using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Nodes;

namespace DentalLab.Core;

public static class BackupCodec
{
    public const int FileLimit = 100 * 1024 * 1024, TotalLimit = 500 * 1024 * 1024, BackupLimit = 750 * 1024 * 1024;
    public static byte[] Derive(string password, byte[] salt) => Rfc2898DeriveBytes.Pbkdf2(Encoding.UTF8.GetBytes(password), salt, 310000, HashAlgorithmName.SHA256, 32);
    // CryptoKit combined representation: 12-byte nonce, ciphertext, 16-byte tag.
    public static byte[] Seal(byte[] data, byte[] key)
    {
        byte[] result = new byte[12 + data.Length + 16];
        RandomNumberGenerator.Fill(result.AsSpan(0, 12));
        using var aes = new AesGcm(key, 16);
        aes.Encrypt(result.AsSpan(0, 12), data, result.AsSpan(12, data.Length), result.AsSpan(12 + data.Length, 16));
        return result;
    }
    public static byte[] Open(byte[] data, byte[] key)
    {
        if (data.Length < 28) throw new InvalidDataException("Dati cifrati incompleti.");
        byte[] result = new byte[data.Length - 28];
        using var aes = new AesGcm(key, 16);
        aes.Decrypt(data.AsSpan(0, 12), data.AsSpan(12, result.Length), data.AsSpan(12 + result.Length, 16), result);
        return result;
    }
    public static byte[] Encode(JsonObject database, Dictionary<string, byte[]> files, string password)
    {
        if (password.EnumerateRunes().Count() < 12) throw new InvalidDataException("Usa almeno 12 caratteri per il backup.");
        var blobs = new JsonObject(); var hashes = new JsonObject();
        foreach (var (id, data) in files) { blobs[id] = Convert.ToBase64String(data); hashes[id] = Convert.ToHexString(SHA256.HashData(data)).ToLowerInvariant(); }
        var payload = new JsonObject { ["version"] = 2, ["database"] = database.DeepClone(), ["files"] = blobs, ["fileHashes"] = hashes };
        Validate(payload);
        byte[] salt = RandomNumberGenerator.GetBytes(16), key = Derive(password, salt);
        try { return "DLBACK02"u8.ToArray().Concat(salt).Concat(Seal(Encoding.UTF8.GetBytes(payload.ToJsonString()), key)).ToArray(); }
        finally { CryptographicOperations.ZeroMemory(key); }
    }
    public static JsonObject Decode(byte[] data, string password)
    {
        if (data.Length <= 52 || data.Length > BackupLimit || !data.AsSpan(0, 8).SequenceEqual("DLBACK02"u8)) throw new InvalidDataException("Formato o dimensione backup non validi.");
        if (password.Length == 0) throw new InvalidDataException("Inserisci la password.");
        var key = Derive(password, data.AsSpan(8, 16).ToArray());
        try {
            var payload = JsonNode.Parse(Open(data.AsSpan(24).ToArray(), key)) as JsonObject ?? throw new InvalidDataException("Backup incompleto.");
            Validate(payload); return payload;
        } finally { CryptographicOperations.ZeroMemory(key); }
    }
    public static string ID(JsonNode? value)
    {
        var text = value?.GetValue<string>() ?? "";
        if (!Guid.TryParseExact(text, "D", out var id) || id.ToString("D").ToUpperInvariant() != text) throw new InvalidDataException("Identificativo non valido.");
        return text;
    }
    public static void ValidateDatabase(JsonObject db)
    {
        if (db["version"]?.GetValue<int>() != 2 || db["entries"] is not JsonArray entries || db["profile"] is not JsonObject || db["counters"] is not JsonObject counters || db["audit"] is not JsonArray || db["movements"] is not JsonArray) throw new InvalidDataException("Versione o struttura archivio non supportata.");
        var ids = new HashSet<string>();
        foreach (var node in entries) {
            if (node is not JsonObject e || !ids.Add(ID(e["id"])) || e["section"] is not JsonValue || e["name"] is not JsonValue) throw new InvalidDataException("Scheda duplicata o incompleta.");
            foreach (var name in new[] { "client", "patient", "detail", "status", "lot" }) _ = e[name]?.GetValue<string>() ?? throw new InvalidDataException("Scheda incompleta.");
            foreach (var name in new[] { "date", "price", "quantity" }) {
                if (!double.TryParse(e[name]?.ToJsonString(), System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out double number) || !double.IsFinite(number)) throw new InvalidDataException("Valore numerico non valido.");
            }
            _ = e["paid"]?.GetValue<bool>() ?? throw new InvalidDataException("Stato pagamento mancante.");
            if (e["attachments"] is not JsonArray legacy || legacy.Count != 0) throw new InvalidDataException("Allegati legacy non migrati.");
        }
        foreach (var (_, value) in counters) if (value is null || value.GetValue<int>() < 0) throw new InvalidDataException("Progressivo non valido.");
    }
    public static void Validate(JsonObject payload)
    {
        int version = payload["version"]?.GetValue<int>() ?? 0;
        if (version is not (1 or 2) || payload["database"] is not JsonObject db || payload["files"] is not JsonObject files) throw new InvalidDataException("Versione backup non supportata.");
        ValidateDatabase(db);
        long total = 0;
        foreach (var (id, value) in files) {
            ID(JsonValue.Create(id));
            if (value is null || value.GetValue<string>().Length > (FileLimit + 2L) / 3 * 4) throw new InvalidDataException("Allegato troppo grande.");
            var data = Convert.FromBase64String(value.GetValue<string>()); total += data.Length;
            if (data.Length > FileLimit || total > TotalLimit) throw new InvalidDataException("Limite allegati superato.");
            if (version == 2 && payload["fileHashes"]?[id]?.GetValue<string>() != Convert.ToHexString(SHA256.HashData(data)).ToLowerInvariant()) throw new InvalidDataException("Impronta allegato non valida.");
        }
        if (version == 2 && (payload["fileHashes"] is not JsonObject hashes || !hashes.Select(p => p.Key).ToHashSet().SetEquals(files.Select(p => p.Key)))) throw new InvalidDataException("Manifesto incompleto.");
        foreach (var e in db["entries"]!.AsArray()) foreach (var f in e?["files"]?.AsArray() ?? new JsonArray()) {
            string id = ID(f?["id"]);
            if (!files.ContainsKey(id)) throw new InvalidDataException("Allegato mancante: " + f?["name"]);
            _ = f?["name"]?.GetValue<string>() ?? throw new InvalidDataException("Nome allegato mancante.");
            _ = f?["category"]?.GetValue<string>() ?? throw new InvalidDataException("Categoria allegato mancante.");
        }
    }
}
