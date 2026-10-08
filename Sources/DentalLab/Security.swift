import Foundation
import CryptoKit
import Security
#if !DIRECT_BUILD
import CryptoSupport
#endif

struct Vault {
    static func random(_ count: Int) throws -> Data { var bytes = [UInt8](repeating: 0, count: count); guard SecRandomCopyBytes(kSecRandomDefault, count, &bytes) == errSecSuccess else { throw AppIssue(message: "Generatore casuale non disponibile.") }; return Data(bytes) }
    static func localKey(create: Bool) throws -> SymmetricKey {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "it.dentallab.vault.v2", kSecAttrAccount as String: "archive"]
        var read = query; read[kSecReturnData as String] = true; read[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?; let status = SecItemCopyMatching(read as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data, data.count == 32 { return SymmetricKey(data: data) }
        guard status == errSecItemNotFound && create else { throw AppIssue(message: "Chiave dell’archivio non disponibile nel Portachiavi. Non creare un nuovo archivio: ripristina un backup portabile con password.") }
        let data = try random(32); var add = query; add[kSecValueData as String] = data; add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        guard SecItemAdd(add as CFDictionary, nil) == errSecSuccess else { throw AppIssue(message: "Impossibile salvare la chiave nel Portachiavi.") }; return SymmetricKey(data: data)
    }
    static func seal(_ data: Data, key: SymmetricKey) throws -> Data { guard let encrypted = try AES.GCM.seal(data, using: key).combined else { throw AppIssue(message: "Cifratura non riuscita.") }; return encrypted }
    static func open(_ data: Data, key: SymmetricKey) throws -> Data { try AES.GCM.open(AES.GCM.SealedBox(combined: data), using: key) }
    static func passwordKey(_ password: String, salt: Data) throws -> SymmetricKey {
        var key = [UInt8](repeating: 0, count: 32); let bytes = Array(password.utf8)
        let status = bytes.withUnsafeBytes { p in salt.withUnsafeBytes { s in dl_derive(p.bindMemory(to: CChar.self).baseAddress!, bytes.count, s.bindMemory(to: UInt8.self).baseAddress!, salt.count, &key) } }
        try require(status == 0, "Derivazione della chiave non riuscita."); return SymmetricKey(data: key)
    }
    static func portable(_ payload: PortableBackup, password: String) throws -> Data {
        try require(password.count >= 12, "Usa una password di almeno 12 caratteri per il backup.")
        let salt = try random(16); let key = try passwordKey(password, salt: salt)
        return Data("DLBACK02".utf8) + salt + (try seal(JSONEncoder().encode(payload), key: key))
    }
    static func restore(_ data: Data, password: String) throws -> PortableBackup {
        try require(data.count > 52 && data.prefix(8) == Data("DLBACK02".utf8), "Formato backup non riconosciuto.")
        try require(!password.isEmpty, "Inserisci la password del backup.")
        let salt = data.subdata(in: 8..<24); let key = try passwordKey(password, salt: salt)
        let payload = try JSONDecoder().decode(PortableBackup.self, from: open(Data(data.dropFirst(24)), key: key))
        try require(payload.version == 1 && payload.database.version == 2, "Versione del backup non supportata.")
        let ids = payload.database.entries.map(\.id); try require(Set(ids).count == ids.count, "Il backup contiene schede duplicate.")
        for e in payload.database.entries { for f in e.files ?? [] { try require(payload.files[f.id.uuidString] != nil, "Allegato mancante nel backup: \(f.name)") } }
        return payload
    }
    static func digest<T: Encodable>(_ value: T) throws -> String { let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; return SHA256.hash(data: try encoder.encode(value)).map { String(format: "%02x", $0) }.joined() }
}
