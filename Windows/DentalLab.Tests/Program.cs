using DentalLab.Core;
using Microsoft.Data.Sqlite;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Nodes;

int checks = 0;
void Check(bool condition, string message) { if (!condition) throw new Exception(message); checks++; }
void Reject(Action operation, string message) { bool rejected = false; try { operation(); } catch { rejected = true; } Check(rejected, message); }
byte[] ReadShared(string path) { using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite); using var bytes = new MemoryStream(); stream.CopyTo(bytes); return bytes.ToArray(); }
string root = Path.Combine(Path.GetTempPath(), "DentalLab-tests-" + Guid.NewGuid()); Directory.CreateDirectory(root);
byte[] key = RandomNumberGenerator.GetBytes(32); const string password = "Password-test-1234";
try {
    var db = LocalArchive.NewDatabase();
    string clientID = LocalArchive.NewID(), workID = LocalArchive.NewID(), fileID = LocalArchive.NewID();
    JsonObject Entry(string id, string section, string title) => new() { ["id"] = id, ["section"] = section, ["name"] = title, ["client"] = "Studio di prova", ["patient"] = "Paziente sintetico", ["detail"] = "Note", ["status"] = "In lavorazione", ["date"] = 812345678.125, ["price"] = 0, ["quantity"] = 0, ["lot"] = "", ["paid"] = false, ["attachments"] = new JsonArray() };
    db["entries"]!.AsArray().Add(Entry(clientID, "Clienti", "Studio di prova"));
    var work = Entry(workID, "Lavori", "Corona sintetica"); work["clientID"] = clientID;
    work["device"] = JsonNode.Parse("""
    {"identifier":"DL-TEST","type":"Protesi fissa","riskClass":"Da valutare","implantable":false,"prescriber":"Dr. Test","institution":"Studio","prescription":"Prova","prescriptionDate":812345678,"teeth":"11","shade":"A2","intendedUse":"","design":"","manufacturing":"","performance":"","risks":"","requirements":"","exceptions":"","substances":"Da valutare","instructions":"","checks":"","reviewer":"","conformityConfirmed":false,"releaseDate":812345678,"toothWorks":[{"tooth":11,"kind":"Corona in zirconia","shadeSystem":"VITA classical A1–D4","shade":"A2"}]}
    """);
    work["files"] = new JsonArray(new JsonObject { ["id"] = fileID, ["name"] = "prescrizione.txt", ["category"] = "Prescrizione" }); db["entries"]!.AsArray().Add(work); db["counters"]!["FT-2026"] = 4;
    byte[] file = Encoding.UTF8.GetBytes("Prescrizione sintetica · àèìòù"); var files = new Dictionary<string, byte[]> { [fileID] = file };
    byte[] encoded = BackupCodec.Encode(db, files, password); JsonObject decoded = BackupCodec.Decode(encoded, password);
    Check(JsonNode.DeepEquals(db, decoded["database"]), "Roundtrip completo e date decimali");
    Check(Convert.FromBase64String(decoded["files"]![fileID]!.GetValue<string>()).SequenceEqual(file), "Allegato e Unicode");
    Reject(() => BackupCodec.Decode(encoded, "sbagliata"), "Password errata accettata");
    var broken = encoded.ToArray(); broken[^1] ^= 1; Reject(() => BackupCodec.Decode(broken, password), "Alterazione accettata");
    Reject(() => BackupCodec.Decode(encoded[..40], password), "Troncamento accettato");
    Reject(() => BackupCodec.Encode(db, files, "breve"), "Password debole accettata");
    var missing = (JsonObject)decoded.DeepClone(); missing["files"]!.AsObject().Clear(); missing["fileHashes"]!.AsObject().Clear(); Reject(() => BackupCodec.Validate(missing), "Allegato mancante accettato");
    var duplicate = (JsonObject)decoded.DeepClone(); duplicate["database"]!["entries"]!.AsArray().Add(duplicate["database"]!["entries"]![0]!.DeepClone()); Reject(() => BackupCodec.Validate(duplicate), "Scheda duplicata accettata");
    var manifest = (JsonObject)decoded.DeepClone(); manifest["fileHashes"]![fileID] = "errato"; Reject(() => BackupCodec.Validate(manifest), "Hash errato accettato");
    var unsafeName = (JsonObject)decoded.DeepClone(); unsafeName["files"]!["../file"] = ""; Reject(() => BackupCodec.Validate(unsafeName), "Percorso non valido accettato");
    var legacy = (JsonObject)decoded.DeepClone(); legacy["version"] = 1; legacy.Remove("fileHashes"); byte[] salt = RandomNumberGenerator.GetBytes(16); byte[] old = "DLBACK02"u8.ToArray().Concat(salt).Concat(BackupCodec.Seal(Encoding.UTF8.GetBytes(legacy.ToJsonString()), BackupCodec.Derive(password, salt))).ToArray(); Check(BackupCodec.Decode(old, password)["version"]!.GetValue<int>() == 1, "Backup v1 non supportato");
    string folder = Path.Combine(root, "local"), backup = Path.Combine(root, "test.dlbackup");
    using (var archive = new LocalArchive(folder, key)) {
        archive.SaveBlob(fileID, file); archive.Save(db); archive.Export(backup, password);
        Check(!Encoding.UTF8.GetString(ReadShared(Path.Combine(folder, "archivio.sqlite"))).Contains("Paziente sintetico"), "Database in chiaro");
        Reject(() => { using var competing = new LocalArchive(folder, key); }, "Seconda istanza accettata");
        var future = (JsonObject)archive.Database.DeepClone(); future["counters"]!["FT-2026"] = 20; archive.Save(future);
        string rescue = archive.Restore(backup, password);
        Check(File.Exists(Path.Combine(rescue, "archivio.sqlite")) && File.Exists(Path.Combine(rescue, "FileCifrati", fileID)), "Copia preventiva incompleta");
        Check(archive.Database["counters"]!["FT-2026"]!.GetValue<int>() == 20, "Contatore abbassato");
        string newID = archive.Database["entries"]![1]!["files"]![0]!["id"]!.GetValue<string>(); Check(newID == fileID && archive.Blob(newID).SequenceEqual(file), "Ripristino allegati e identità");
        JsonObject before = (JsonObject)archive.Database.DeepClone(); Reject(() => archive.Restore(backup, "sbagliata"), "Ripristino con password errata"); Check(JsonNode.DeepEquals(before, archive.Database), "Archivio cambiato dopo errore");
        for (int i = 0; i < 70; i++) archive.Save(archive.Database);
        using var sql = new SqliteConnection($"Data Source={Path.Combine(folder, "archivio.sqlite")};Pooling=False"); sql.Open(); using var command = sql.CreateCommand(); command.CommandText = "SELECT COUNT(*) FROM revisions"; Check((long)command.ExecuteScalar()! == 60, "Storico non limitato a 60");
    }
    using (var reopened = new LocalArchive(folder, key)) { Check(reopened.Database["entries"]!.AsArray().Count == 2, "Persistenza dopo riavvio"); reopened.VerifySQLite(); }
    foreach (string point in new[] { "after-rescue", "after-attachment", "before-commit" }) {
        bool inject = false;
        using var target = new LocalArchive(Path.Combine(root, point), key) { FailureInjection = p => { if (inject && p == point) throw new IOException("Interruzione simulata"); } };
        var before = (JsonObject)target.Database.DeepClone(); inject = true;
        Reject(() => target.Restore(backup, password), "Interruzione non intercettata: " + point);
        Check(JsonNode.DeepEquals(before, target.Database), "Dati persi: " + point);
        string blobFolder = Path.Combine(target.Folder, "FileCifrati"); Check(!Directory.Exists(blobFolder) || Directory.GetFiles(blobFolder,"*",SearchOption.AllDirectories).Length == 0, "Allegati parziali: " + point);
        inject = false; target.VerifySQLite();
    }
    string badFolder = Path.Combine(root, "bad"); Directory.CreateDirectory(badFolder); byte[] corruption = "corrotto"u8.ToArray(); File.WriteAllBytes(Path.Combine(badFolder, "archivio.sqlite"), corruption);
    Reject(() => { using var badArchive = new LocalArchive(badFolder, key); }, "Archivio corrotto accettato"); Check(File.ReadAllBytes(Path.Combine(badFolder, "archivio.sqlite")).SequenceEqual(corruption), "Archivio corrotto sovrascritto");
    if (OperatingSystem.IsWindows()) {
        string dpapiFolder = Path.Combine(root, "dpapi"); using (var a = new LocalArchive(dpapiFolder)) { a.Save(db); }
        using (var a = new LocalArchive(dpapiFolder)) Check(JsonNode.DeepEquals(a.Database, db), "DPAPI dopo riavvio");
        File.Delete(Path.Combine(dpapiFolder, "local.key")); byte[] original = File.ReadAllBytes(Path.Combine(dpapiFolder, "archivio.sqlite"));
        Reject(() => { using var a = new LocalArchive(dpapiFolder); }, "Chiave mancante ricreata"); Check(File.ReadAllBytes(Path.Combine(dpapiFolder, "archivio.sqlite")).SequenceEqual(original), "Archivio senza chiave sovrascritto");
    }
    string? fixtureOutput = Environment.GetEnvironmentVariable("DENTALLAB_FIXTURE_OUTPUT");
    if (fixtureOutput != null) { Directory.CreateDirectory(fixtureOutput); File.WriteAllBytes(Path.Combine(fixtureOutput, "windows.dlbackup"), encoded); }
    string? fixtureInput = Environment.GetEnvironmentVariable("DENTALLAB_FIXTURE_INPUT");
    if (fixtureInput != null) {
        var swift = BackupCodec.Decode(File.ReadAllBytes(Path.Combine(fixtureInput, "swift.dlbackup")), password);
        Check(swift["database"]!["entries"]!.AsArray().Any(e => e?["device"]?["toothWorks"]?.AsArray().Any(t => t?["shade"]?.GetValue<string>() == "A2") == true), "Odontogramma Swift non letto");
        Check(swift["files"]!.AsObject().Count > 0, "Allegati Swift non letti");
    }
    Console.WriteLine($"PASS · {checks} verifiche: backup, compatibilità, SQLite, cifratura, blocco istanza, DPAPI e rollback.");
} finally { SqliteConnection.ClearAllPools(); Directory.Delete(root, true); CryptographicOperations.ZeroMemory(key); }
