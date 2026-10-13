using Microsoft.Data.Sqlite;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Nodes;

namespace DentalLab.Core;

public sealed class LocalArchive : IDisposable
{
    private readonly FileStream archiveLock;
    private readonly byte[] key;
    private readonly SqliteConnection connection;
    public string Folder { get; }
    public JsonObject Database { get; private set; }
    public Action<string>? FailureInjection { get; init; } // Exercised by recovery tests.
    public LocalArchive(string folder, byte[]? testKey = null)
    {
        Folder = Path.GetFullPath(folder); Directory.CreateDirectory(Folder);
        // FileShare.None releases automatically after exit or crash, without stale lock files.
        archiveLock = new FileStream(Path.Combine(Folder, ".lock"), FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None);
        bool existing = File.Exists(Path.Combine(Folder, "archivio.sqlite"));
        connection = new SqliteConnection(new SqliteConnectionStringBuilder { DataSource = Path.Combine(Folder, "archivio.sqlite"), Mode = existing ? SqliteOpenMode.ReadWrite : SqliteOpenMode.ReadWriteCreate, Pooling = false }.ToString());
        key = [];
        Database = new JsonObject();
        try {
            key = testKey?.ToArray() ?? LoadKey(existing);
            connection.Open(); Execute("PRAGMA synchronous=FULL");
            if (!existing) Execute("CREATE TABLE archive(id INTEGER PRIMARY KEY CHECK(id=1),payload BLOB NOT NULL); CREATE TABLE revisions(id INTEGER PRIMARY KEY AUTOINCREMENT,payload BLOB NOT NULL); PRAGMA user_version=1");
            if (Convert.ToInt32(Scalar("PRAGMA user_version")) != 1) throw new InvalidDataException("Versione SQLite non supportata.");
            VerifySQLite();
            if (existing) {
                Database = JsonNode.Parse(BackupCodec.Open((byte[])Scalar("SELECT payload FROM archive WHERE id=1")!, key))!.AsObject();
                BackupCodec.ValidateDatabase(Database);
            } else {
                Database = NewDatabase(); Save(Database, false);
            }
        } catch { connection.Dispose(); archiveLock.Dispose(); CryptographicOperations.ZeroMemory(key); throw; }
    }
    private byte[] LoadKey(bool existing)
    {
        if (!OperatingSystem.IsWindows()) throw new PlatformNotSupportedException("La chiave locale richiede Windows DPAPI.");
        var path = Path.Combine(Folder, "local.key");
        if (File.Exists(path)) return ProtectedData.Unprotect(File.ReadAllBytes(path), null, DataProtectionScope.CurrentUser);
        if (existing) throw new InvalidDataException("Chiave locale mancante. Ripristina il backup in una nuova cartella con lo stesso programma.");
        var result = RandomNumberGenerator.GetBytes(32);
        AtomicWrite(path, ProtectedData.Protect(result, null, DataProtectionScope.CurrentUser)); return result;
    }
    public static JsonObject NewDatabase() => JsonNode.Parse("""
    {"version":2,"entries":[],"profile":{"name":"","contact":{"vat":"","taxCode":"","address":"","zip":"","city":"","province":"","email":"","phone":"","recipient":"0000000","pec":""},"productionSites":"","representative":"Non applicabile","registration":"","prrc":"","iban":"","regime":"RF01","privacyProcedure":"","qualityProcedure":""},"movements":[],"audit":[],"counters":{}}
    """)!.AsObject();
    public static string NewID() => Guid.NewGuid().ToString("D").ToUpperInvariant();
    public static double SwiftNow() => (DateTimeOffset.UtcNow - new DateTimeOffset(2001, 1, 1, 0, 0, 0, TimeSpan.Zero)).TotalSeconds;
    public static void Audit(JsonObject db, string action, string? recordID = null) => db["audit"]!.AsArray().Add(new JsonObject { ["id"] = NewID(), ["date"] = SwiftNow(), ["action"] = action, ["label"] = action, ["recordID"] = recordID });
    private void Execute(string sql) { using var cmd = connection.CreateCommand(); cmd.CommandText = sql; cmd.ExecuteNonQuery(); }
    private object? Scalar(string sql) { using var cmd = connection.CreateCommand(); cmd.CommandText = sql; return cmd.ExecuteScalar(); }
    public void VerifySQLite() { if ((string?)Scalar("PRAGMA integrity_check") != "ok") throw new InvalidDataException("Archivio SQLite danneggiato."); }
    public void Save(JsonObject next, bool history = true)
    {
        BackupCodec.ValidateDatabase(next);
        byte[] payload = BackupCodec.Seal(Encoding.UTF8.GetBytes(next.ToJsonString()), key);
        using var tx = connection.BeginTransaction();
        using var cmd = connection.CreateCommand(); cmd.Transaction = tx;
        if (history) { cmd.CommandText = "INSERT INTO revisions(payload) SELECT payload FROM archive WHERE id=1"; cmd.ExecuteNonQuery(); }
        cmd.CommandText = "INSERT OR REPLACE INTO archive(id,payload) VALUES(1,$p)"; cmd.Parameters.AddWithValue("$p", payload); cmd.ExecuteNonQuery();
        cmd.CommandText = "DELETE FROM revisions WHERE id NOT IN (SELECT id FROM revisions ORDER BY id DESC LIMIT 60)"; cmd.Parameters.Clear(); cmd.ExecuteNonQuery();
        FailureInjection?.Invoke("before-commit"); tx.Commit(); Database = (JsonObject)next.DeepClone();
    }
    public byte[] Blob(string id) => BackupCodec.Open(File.ReadAllBytes(BlobPath(id)), key);
    private string BlobFolder(JsonObject db) => db["fileGeneration"] == null ? Path.Combine(Folder, "FileCifrati") : Path.Combine(Folder, "FileCifrati", BackupCodec.ID(db["fileGeneration"]));
    private string BlobPath(string id) => Path.Combine(BlobFolder(Database), BackupCodec.ID(JsonValue.Create(id)));
    public void SaveBlob(string id, byte[] data)
    {
        if (data.Length > BackupCodec.FileLimit) throw new InvalidDataException("Limite allegato: 100 MB.");
        Directory.CreateDirectory(BlobFolder(Database)); AtomicWrite(BlobPath(id), BackupCodec.Seal(data, key));
    }
    public static void AtomicWrite(string path, byte[] data)
    {
        string absolute = Path.GetFullPath(path), temporary = absolute + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try {
            using (var stream = new FileStream(temporary, FileMode.CreateNew, FileAccess.Write, FileShare.None)) { stream.Write(data); stream.Flush(true); }
            File.Move(temporary, absolute, true);
        } finally { if (File.Exists(temporary)) File.Delete(temporary); }
    }
    public JsonObject VerifyBackup(string path, string password)
    {
        if (new FileInfo(path).Length > BackupCodec.BackupLimit) throw new InvalidDataException("Backup superiore a 750 MB.");
        return BackupCodec.Decode(File.ReadAllBytes(path), password);
    }
    public void Export(string path, string password)
    {
        VerifySQLite(); var files = new Dictionary<string, byte[]>(); long size = 0;
        foreach (var e in Database["entries"]!.AsArray()) foreach (var f in e?["files"]?.AsArray() ?? new JsonArray()) {
            string id = BackupCodec.ID(f?["id"]); if (!files.ContainsKey(id)) { byte[] data = Blob(id); size += data.Length; if (size > BackupCodec.TotalLimit) throw new InvalidDataException("Allegati oltre 500 MB."); files.Add(id, data); }
        }
        var portableDatabase = (JsonObject)Database.DeepClone(); portableDatabase.Remove("fileGeneration");
        byte[] encoded = BackupCodec.Encode(portableDatabase, files, password);
        _ = BackupCodec.Decode(encoded, password); AtomicWrite(path, encoded); _ = VerifyBackup(path, password);
    }
    private string Rescue()
    {
        string rescue = Path.Combine(Folder, "PrimaDelRipristino", NewID()); Directory.CreateDirectory(rescue);
        using (var destination = new SqliteConnection($"Data Source={Path.Combine(rescue, "archivio.sqlite")};Pooling=False")) {
            destination.Open(); connection.BackupDatabase(destination);
            using var command = destination.CreateCommand(); command.CommandText = "PRAGMA integrity_check";
            if ((string?)command.ExecuteScalar() != "ok") throw new InvalidDataException("Copia preventiva non valida.");
        }
        if (File.Exists(Path.Combine(Folder, "local.key"))) File.Copy(Path.Combine(Folder, "local.key"), Path.Combine(rescue, "local.key"));
        foreach (string dir in new[] { "FileCifrati", "Allegati" }) {
            if (!Directory.Exists(Path.Combine(Folder, dir))) continue;
            string target = Path.Combine(rescue, dir); Directory.CreateDirectory(target);
            foreach (var file in Directory.GetFiles(Path.Combine(Folder, dir), "*", SearchOption.AllDirectories)) {
                string destination = Path.Combine(target, Path.GetRelativePath(Path.Combine(Folder, dir), file)); Directory.CreateDirectory(Path.GetDirectoryName(destination)!); File.Copy(file, destination);
            }
        }
        FailureInjection?.Invoke("after-rescue"); return rescue;
    }
    public string Restore(string path, string password)
    {
        JsonObject payload = VerifyBackup(path, password); string rescue = Rescue();
        JsonObject next = (JsonObject)payload["database"]!.DeepClone();
        string generation = NewID(); next["fileGeneration"] = generation;
        string staged = BlobFolder(next); bool completed = false;
        try {
            Directory.CreateDirectory(staged);
            foreach (var (oldID, value) in payload["files"]!.AsObject()) {
                var data = Convert.FromBase64String(value!.GetValue<string>()); string file = Path.Combine(staged, oldID); AtomicWrite(file, BackupCodec.Seal(data, key));
                if (!BackupCodec.Open(File.ReadAllBytes(file), key).AsSpan().SequenceEqual(data)) throw new InvalidDataException("Verifica allegato fallita.");
                FailureInjection?.Invoke("after-attachment");
            }
            next.Remove("calendarLink"); next["dailyAccess"] = Database["dailyAccess"]?.DeepClone();
            foreach (var (series, number) in Database["counters"]!.AsObject()) next["counters"]![series] = Math.Max(number!.GetValue<int>(), next["counters"]![series]?.GetValue<int>() ?? 0);
            Audit(next, "Ripristino backup completo"); Save(next); completed = true; return rescue;
        } finally { if (!completed && Directory.Exists(staged)) Directory.Delete(staged, true); }
    }
    public void Dispose() { connection.Dispose(); archiveLock.Dispose(); CryptographicOperations.ZeroMemory(key); }
}
