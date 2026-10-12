using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Nodes;

namespace DentalLab.Core;

// Shared files are an exchange journal, never a remotely opened SQLite database.
// The create-new reservation deliberately has no timeout: a lost client cannot
// silently regain write access after another workstation takes over.
public sealed class SharedArchiveSession
{
    private readonly string folder, statePath, password, token = Guid.NewGuid().ToString("D").ToUpperInvariant();
    private readonly Action<string,string> export, restore;
    private readonly Func<string> fingerprint;
    private string baseline = "";
    private bool reserved;
    public SharedArchiveSession(string folder, string statePath, string password, Func<string> fingerprint, Action<string,string> export, Action<string,string> restore)
    { this.folder = Path.GetFullPath(folder); this.statePath = statePath; this.password = password; this.fingerprint = fingerprint; this.export = export; this.restore = restore; }
    private string Lease => Path.Combine(folder, ".dentallab-session");
    private string Head => Path.Combine(folder, "dentallab-head.json");
    private static string Hash(byte[] bytes) => Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant();
    private string ReadHead() { try { return File.ReadAllText(Head); } catch (FileNotFoundException) { return ""; } }
    private void Own()
    {
        if (!reserved || !Directory.Exists(folder) || File.ReadAllText(Lease) != token) throw new IOException("La sessione sul disco non è disponibile. Le modifiche locali sono conservate. Ricollega VPN e disco; non avviare un altro computer.");
        if (ReadHead() != baseline) throw new IOException("Conflitto: la versione sul disco è cambiata. Nessun dato remoto è stato sovrascritto.");
    }
    private string Backup(string head)
    {
        var item = JsonNode.Parse(head)!.AsObject();
        if (item["version"]?.GetValue<int>() != 1 || !Guid.TryParseExact(item["revision"]?.GetValue<string>(), "D", out var id)) throw new InvalidDataException("Manifesto di sincronizzazione non valido.");
        string path = Path.Combine(folder, id.ToString("D").ToUpperInvariant() + ".dlbackup");
        if (new FileInfo(path).Length > BackupCodec.BackupLimit || Hash(File.ReadAllBytes(path)) != item["sha256"]?.GetValue<string>()) throw new InvalidDataException("Backup condiviso incompleto o alterato.");
        return path;
    }
    private void Remember() => LocalArchive.AtomicWrite(statePath, Encoding.UTF8.GetBytes(new JsonObject { ["folder"] = folder, ["head"] = baseline, ["fingerprint"] = fingerprint() }.ToJsonString()));
    public void Open(bool initialize = false)
    {
        if (reserved) throw new InvalidOperationException("Sessione già aperta.");
        if (!Directory.Exists(folder)) throw new DirectoryNotFoundException("Disco non raggiungibile. Collega la VPN e apri la cartella condivisa.");
        if (password.EnumerateRunes().Count() < 12) throw new InvalidDataException("Usa una password condivisa di almeno 12 caratteri.");
        try { using var stream = new FileStream(Lease, FileMode.CreateNew, FileAccess.Write, FileShare.None); byte[] bytes = Encoding.UTF8.GetBytes(token); stream.Write(bytes); stream.Flush(true); }
        catch (IOException issue) { throw new IOException("Disco occupato da un’altra postazione oppure non scrivibile. Chiudi prima DentalLab sull’altra postazione. Dopo un crash verifica tutte le postazioni prima di rimuovere .dentallab-session.", issue); }
        reserved = true;
        try {
            baseline = ReadHead();
            JsonObject? previous = File.Exists(statePath) ? JsonNode.Parse(File.ReadAllText(statePath))!.AsObject() : null;
            bool known = previous?["folder"]?.GetValue<string>() == folder;
            if (!known && !initialize) throw new InvalidOperationException("Configura prima questa postazione: il primo collegamento richiede una conferma esplicita.");
            if (known && previous!["head"]!.GetValue<string>() != baseline && previous["fingerprint"]!.GetValue<string>() != fingerprint()) throw new InvalidOperationException("Conflitto: modifiche locali e una nuova versione sul disco. Conserva un backup locale e risolvi il conflitto prima di continuare.");
            if (baseline.Length > 0) {
                string path = Backup(baseline); _ = BackupCodec.Decode(File.ReadAllBytes(path), password);
                if (!known || previous!["head"]!.GetValue<string>() != baseline) { Own(); restore(path, password); Remember(); }
            } else {
                if (known && previous!["head"]!.GetValue<string>().Length > 0) throw new IOException("La versione condivisa è scomparsa. Nessuna reinizializzazione automatica.");
                Publish();
            }
        } catch { Release(); throw; }
    }
    public void Publish()
    {
        Own(); string revision = Guid.NewGuid().ToString("D").ToUpperInvariant();
        string path = Path.Combine(folder, revision + ".dlbackup"); export(path, password);
        _ = BackupCodec.Decode(File.ReadAllBytes(path), password); Own();
        string head = new JsonObject { ["version"] = 1, ["revision"] = revision, ["sha256"] = Hash(File.ReadAllBytes(path)) }.ToJsonString();
        LocalArchive.AtomicWrite(Head, Encoding.UTF8.GetBytes(head)); baseline = head; Remember();
    }
    public void Finish() { Publish(); Release(); }
    public void Release()
    {
        if (!reserved) return;
        // Never delete another client's reservation; retain ours if release fails.
        if (File.ReadAllText(Lease) != token) throw new IOException("Prenotazione cambiata: rilascio annullato.");
        File.Delete(Lease); reserved = false;
    }
    public static string Fingerprint(JsonObject database)
    {
        var clone = (JsonObject)database.DeepClone(); foreach (var key in new[]{"audit","dailyAccess","calendarLink","fileGeneration"}) clone.Remove(key);
        // Ordering is only compared within one local installation.
        return Hash(Encoding.UTF8.GetBytes(clone.ToJsonString()));
    }
}
