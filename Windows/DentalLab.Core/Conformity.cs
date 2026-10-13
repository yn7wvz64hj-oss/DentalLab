using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace DentalLab.Core;

public static class Conformity
{
    public sealed record Block(string Title, string Text);
    public static string Text(JsonNode? node, string key) => node?[key]?.GetValue<string>() ?? "";
    public static JsonObject Draft(JsonObject work)
    {
        if (Text(work,"section") != "Lavori") throw new InvalidDataException("Seleziona una scheda lavoro.");
        var entry = (JsonObject)work.DeepClone(); entry["id"] = LocalArchive.NewID(); entry["workID"] = Text(work,"id"); entry["section"] = "Conformità";
        entry["name"] = "Conformità · " + Text(work,"name"); entry["date"] = LocalArchive.SwiftNow(); entry["created"] = LocalArchive.SwiftNow();
        foreach (var key in new[]{"issued","archived","updated","frozenMaterials","payments"}) entry.Remove(key);
        return entry;
    }
    public static List<string> Missing(JsonObject entry, JsonObject profile)
    {
        var d = entry["device"]; var missing = new List<string>();
        if (Text(profile,"name").Length == 0 || Address(profile["contact"]).Length == 0 || Text(profile,"productionSites").Length == 0) missing.Add("Fabbricante, indirizzo e luoghi di fabbricazione");
        if (Text(profile,"representative").Length == 0) missing.Add("Mandatario o indicazione Non applicabile");
        if (Text(d,"identifier").Length == 0) missing.Add("Identificativo univoco del dispositivo");
        if (Text(entry,"patient").Length == 0) missing.Add("Paziente: nome, acronimo o codice");
        if (Text(d,"prescriber").Length == 0) missing.Add("Prescrittore autorizzato");
        if (Text(d,"prescription").Length == 0) missing.Add("Caratteristiche specifiche della prescrizione");
        if (!(entry["files"]?.AsArray().Any(f => Text(f,"category") == "Prescrizione") ?? false)) missing.Add("Prescrizione allegata al fascicolo");
        if (Text(d,"requirements").Length == 0 || d?["conformityConfirmed"]?.GetValue<bool>() != true) missing.Add("Verifica dei requisiti di sicurezza e prestazione");
        if (Text(d,"substances") is "" or "Da valutare") missing.Add("Valutazione di sostanze medicinali e tessuti/cellule");
        if (new[]{"design","manufacturing","performance","risks"}.Any(k => Text(d,k).Length == 0)) missing.Add("Progettazione, fabbricazione, prestazioni e rischi documentati");
        if (new[]{"checks","instructions","reviewer"}.Any(k => Text(d,k).Length == 0)) missing.Add("Controlli, istruzioni e responsabile della verifica");
        if (!new[]{"I","IIa","IIb","III"}.Contains(Text(d,"riskClass"))) missing.Add("Classificazione del dispositivo");
        if (Text(d,"riskClass") == "III" && d?["implantable"]?.GetValue<bool>() == true) missing.Add("Classe III impiantabile: procedura aggiuntiva con organismo notificato non gestita da questa versione");
        return missing;
    }
    public static void Save(LocalArchive archive, JsonObject entry, JsonObject profile, bool register = false)
    {
        if (Text(entry,"section") != "Conformità" || string.IsNullOrWhiteSpace(Text(entry,"name")) || entry["issued"] != null || entry["archived"]?.GetValue<bool>() == true) throw new InvalidDataException("Dichiarazione non modificabile o senza titolo.");
        var next = (JsonObject)archive.Database.DeepClone(); var entries = next["entries"]!.AsArray(); var existing = entries.FirstOrDefault(e => Text(e,"id") == Text(entry,"id"));
        if (existing?["issued"] != null || existing?["archived"]?.GetValue<bool>() == true) throw new InvalidDataException("La dichiarazione salvata è già registrata o archiviata.");
        var value = (JsonObject)entry.DeepClone(); value["updated"] = LocalArchive.SwiftNow();
        if (register) {
            var missing = Missing(value,profile); if (missing.Count > 0) throw new InvalidDataException("Completa il fascicolo:\n" + string.Join("\n",missing));
            foreach (var file in value["files"]?.AsArray() ?? new JsonArray()) _ = archive.Blob(Text(file,"id"));
            int year = new DateTime(2001,1,1,0,0,0,DateTimeKind.Utc).AddSeconds(value["date"]!.GetValue<double>()).ToLocalTime().Year;
            string series = $"DSM-{year}"; int number = checked((next["counters"]![series]?.GetValue<int>() ?? 0) + 1); next["counters"]![series] = number;
            var customer = entries.FirstOrDefault(e => Text(e,"id") == Text(value,"clientID"));
            value["frozenMaterials"] = Materials(value,next);
            value["issued"] = new JsonObject { ["number"] = $"{series}-{number:D4}", ["date"] = LocalArchive.SwiftNow(), ["profile"] = profile.DeepClone(), ["customerName"] = customer == null ? Text(value,"client") : Text(customer,"name"), ["customer"] = (customer?["contact"] ?? LocalArchive.NewDatabase()["profile"]!["contact"]!).DeepClone(), ["digest"] = "" };
            // Informational local fingerprint, never an electronic signature.
            value["issued"]!["digest"] = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value.ToJsonString()))).ToLowerInvariant();
        }
        next["profile"] = profile.DeepClone(); if (existing == null) entries.Add(value); else entries[entries.IndexOf(existing)] = value;
        LocalArchive.Audit(next,register ? "Registrazione dichiarazione Windows" : "Bozza dichiarazione Windows",Text(value,"id")); archive.Save(next);
    }
    public static string Address(JsonNode? c) => string.Join(", ",new[]{Text(c,"address"),(Text(c,"zip")+" "+Text(c,"city")).Trim(),Text(c,"province")}.Where(s=>s.Length>0));
    public static string Materials(JsonObject entry, JsonObject db)
    {
        if (entry["frozenMaterials"] != null) return Text(entry,"frozenMaterials");
        var work = db["entries"]!.AsArray().FirstOrDefault(e => Text(e,"id") == Text(entry,"workID")) ?? entry;
        var lines = new List<string>(); if (Text(entry,"lot").Length>0) lines.Add(Text(entry,"lot"));
        foreach (var use in work["materialUses"]?.AsArray() ?? new JsonArray()) { var stock = db["entries"]!.AsArray().FirstOrDefault(e=>Text(e,"id")==Text(use,"stockID")); lines.Add($"{(stock == null ? "Materiale" : Text(stock,"name"))} · lotto {Text(stock,"lot")} · {use?["quantity"]} {Text(stock,"unit")}"); }
        return string.Join("\n",lines);
    }
    public static List<Block> Blocks(JsonObject entry, JsonObject db)
    {
        var p = entry["issued"]?["profile"] ?? db["profile"]!; var d = entry["device"]; string D(string k) => Text(d,k);
        var blocks = new List<Block> {
            new("Laboratorio",$"{Text(p,"name")}\n{Address(p["contact"])}\nP.IVA {Text(p["contact"],"vat")} · CF {Text(p["contact"],"taxCode")}\n{Text(p["contact"],"email")} · {Text(p["contact"],"phone")}"),
            new("Fabbricazione",$"Luoghi: {Text(p,"productionSites")}\nMandatario: {Text(p,"representative")}\nRegistrazione fabbricante: {Text(p,"registration")}"),
            new("Identificazione e destinazione",$"Dispositivo: {D("identifier")} · {D("type")}\nClasse dichiarata dal fabbricante: {D("riskClass")}\nPaziente/utilizzatore: {Text(entry,"patient")}\nStudio: {Text(entry,"client")}\nPrescrittore: {D("prescriber")}\nIstituzione sanitaria: {D("institution")}\nDestinazione d’uso: {D("intendedUse")}"),
            new("Prescrizione e caratteristiche specifiche",$"Data prescrizione: {Date(d?["prescriptionDate"])}\n{D("prescription")}"),
            new("Dichiarazione del fabbricante",$"Il fabbricante dichiara che il dispositivo è destinato esclusivamente al paziente/utilizzatore sopra identificato. Verifica dei requisiti applicabili dell’Allegato I:\n{D("requirements")}\nConformità confermata dal fabbricante: {(d?["conformityConfirmed"]?.GetValue<bool>() == true ? "Sì" : "Non confermata")}\nEccezioni e motivazioni: {(D("exceptions").Length == 0 ? "Nessuna eccezione indicata dal fabbricante" : D("exceptions"))}\nSostanze medicinali, derivati del sangue e tessuti/cellule: {D("substances")}"),
            new("Controlli e tracciabilità",$"{D("checks")}\nMateriali/lotti: {Materials(entry,db)}\nResponsabile: {D("reviewer")}\nImmissione sul mercato dichiarata: {Date(d?["releaseDate"])}"),
            new("Istruzioni",D("instructions")),
            new("Sottoscrizione","Luogo e data: __________________________\nFirma del fabbricante: __________________________\nRiferimento: Regolamento (UE) 2017/745, Allegato XIII. La registrazione informatica non costituisce firma elettronica né certificazione di conformità.")
        };
        string dental = d?["toothWorks"] is JsonArray works ? string.Join("\n",works.OrderBy(t=>t!["tooth"]!.GetValue<int>()).Select(t=>$"{t!["tooth"]}: {Text(t,"kind")} · {Text(t,"shadeSystem")} {Text(t,"shade")}")) : $"{D("teeth")} · {D("shade")}";
        blocks.Insert(4,new("Lavorazioni e colori per dente",dental));
        if (entry["issued"] == null) blocks.Insert(0,new("BOZZA · documento non registrato","Verifica i dati e completa il fascicolo prima della registrazione. Questa bozza non attesta una conformità confermata."));
        return blocks;
    }
    private static string Date(JsonNode? value) => value == null ? "" : new DateTime(2001,1,1,0,0,0,DateTimeKind.Utc).AddSeconds(value.GetValue<double>()).ToLocalTime().ToString("dd/MM/yyyy");
}
