using DentalLab.Core;
using System.Text.Json.Nodes;

static class SharedArchiveChecks
{
    public static int Run(string root, byte[] key, string password)
    {
        int count = 0;
        void Check(bool value) { if (!value) throw new Exception("Shared archive assertion failed."); count++; }
        void Reject(Action action) { bool refused = false; try { action(); } catch { refused = true; } Check(refused); }
        string remote = Path.Combine(root,"shared"); Directory.CreateDirectory(remote);
        using var a = new LocalArchive(Path.Combine(root,"sync-a"),key);
        using var b = new LocalArchive(Path.Combine(root,"sync-b"),key);
        SharedArchiveSession Session(LocalArchive local, string secret = "") => new(remote,Path.Combine(local.Folder,"sync-state.json"),secret.Length == 0 ? password : secret,() => SharedArchiveSession.Fingerprint(local.Database),local.Export,(path,pw) => local.Restore(path,pw));
        var first = Session(a); first.Open(true);
        Check(File.Exists(Path.Combine(remote,"dentallab-head.json")));
        Reject(() => Session(b).Open(true)); // Two devices cannot start together.
        var next = (JsonObject)a.Database.DeepClone(); next["profile"]!["name"] = "Versione A"; a.Save(next);
        string offline = remote + "-offline"; Directory.Move(remote, offline);
        Reject(first.Finish); Check(a.Database["profile"]!["name"]!.GetValue<string>() == "Versione A");
        Directory.Move(offline,remote); first.Finish();
        var second = Session(b); second.Open(true);
        Check(b.Database["profile"]!["name"]!.GetValue<string>() == "Versione A");
        Check(Directory.Exists(Path.Combine(b.Folder,"PrimaDelRipristino")));
        next = (JsonObject)b.Database.DeepClone(); next["profile"]!["name"] = "Versione B"; b.Save(next); second.Finish();
        var resumed = Session(a); resumed.Open(); Check(a.Database["profile"]!["name"]!.GetValue<string>() == "Versione B"); resumed.Finish();
        Reject(() => Session(b,"Password-errata-123").Open());
        Check(!File.Exists(Path.Combine(remote,".dentallab-session")));
        next = (JsonObject)b.Database.DeepClone(); next["profile"]!["name"] = "Modifiche offline"; b.Save(next);
        var writer = Session(a); writer.Open(); writer.Finish();
        string oldHead = File.ReadAllText(Path.Combine(remote,"dentallab-head.json"));
        var failed = new SharedArchiveSession(remote,Path.Combine(a.Folder,"sync-state.json"),password,() => SharedArchiveSession.Fingerprint(a.Database),(_,_) => throw new IOException("VPN interrotta"),(path,pw) => a.Restore(path,pw));
        failed.Open(); Reject(failed.Publish); Check(File.ReadAllText(Path.Combine(remote,"dentallab-head.json")) == oldHead); failed.Release();
        if (Environment.GetEnvironmentVariable("DENTALLAB_FIXTURE_OUTPUT") is string output) {
            string target = Path.Combine(output,"shared"); Directory.CreateDirectory(target);
            File.Copy(Path.Combine(remote,"dentallab-head.json"),Path.Combine(target,"dentallab-head.json"),true);
            string id = JsonNode.Parse(oldHead)!["revision"]!.GetValue<string>(); File.Copy(Path.Combine(remote,id+".dlbackup"),Path.Combine(target,id+".dlbackup"),true);
        }
        if (Environment.GetEnvironmentVariable("DENTALLAB_FIXTURE_INPUT") is string input && Directory.Exists(Path.Combine(input,"shared"))) {
            string incoming = Path.Combine(root,"incoming-sync"); Directory.CreateDirectory(incoming);
            foreach (var file in Directory.GetFiles(Path.Combine(input,"shared"))) File.Copy(file,Path.Combine(incoming,Path.GetFileName(file)));
            using var imported = new LocalArchive(Path.Combine(root,"cross-sync"),key);
            var cross = new SharedArchiveSession(incoming,Path.Combine(imported.Folder,"sync-state.json"),password,() => SharedArchiveSession.Fingerprint(imported.Database),imported.Export,(path,pw) => imported.Restore(path,pw));
            cross.Open(true); Check(imported.Database["profile"]!["name"]!.GetValue<string>() == "Cross Swift"); cross.Finish();
        }
        Reject(() => Session(b).Open());
        Check(b.Database["profile"]!["name"]!.GetValue<string>() == "Modifiche offline");
        Check(File.ReadAllText(Path.Combine(remote,"dentallab-head.json")) == oldHead);
        writer = Session(a); writer.Open();
        File.WriteAllText(Path.Combine(remote,"dentallab-head.json"),"alterato");
        Reject(writer.Publish); Check(File.ReadAllText(Path.Combine(remote,"dentallab-head.json")) == "alterato");
        File.WriteAllText(Path.Combine(remote,"dentallab-head.json"),oldHead); writer.Release();
        File.Delete(Path.Combine(remote,"dentallab-head.json")); Reject(() => Session(a).Open());
        Check(!File.Exists(Path.Combine(remote,"dentallab-head.json")));
        return count;
    }
}
