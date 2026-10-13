import Foundation
import CryptoKit
import Darwin

final class SharedArchiveSession {
    struct Head: Codable { var version = 1; let revision: String; let sha256: String }
    struct State: Codable { let folder: String; let head: String; let fingerprint: String }
    let folder: URL, stateURL: URL
    private let password: String, token = UUID().uuidString
    private let fingerprint: () throws -> String
    private let export: (URL, String) throws -> Void, restore: (URL, String) throws -> Void
    private var baseline = Data(), reserved = false
    init(folder: URL, stateURL: URL, password: String, fingerprint: @escaping () throws -> String, export: @escaping (URL, String) throws -> Void, restore: @escaping (URL, String) throws -> Void) {
        self.folder = folder.standardizedFileURL; self.stateURL = stateURL; self.password = password; self.fingerprint = fingerprint; self.export = export; self.restore = restore
    }
    private var lease: URL { folder.appendingPathComponent(".dentallab-session") }
    private var headURL: URL { folder.appendingPathComponent("dentallab-head.json") }
    private func readHead() throws -> Data {
        do { return try Data(contentsOf: headURL) }
        catch let error as NSError { if error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError { return Data() }; throw error }
    }
    private func own() throws {
        try require(reserved && (try String(contentsOf: lease, encoding: .utf8)) == token, "Sessione sul disco non disponibile. Ricollega VPN e disco; le modifiche locali sono conservate.")
        try require(try readHead() == baseline, "Conflitto: la versione sul disco è cambiata. Nessun dato remoto è stato sovrascritto.")
    }
    private func backup(_ data: Data) throws -> URL {
        let head = try JSONDecoder().decode(Head.self, from: data)
        try require(head.version == 1 && UUID(uuidString: head.revision)?.uuidString == head.revision, "Manifesto di sincronizzazione non valido.")
        let url = folder.appendingPathComponent(head.revision + ".dlbackup")
        try require((try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 750 * 1024 * 1024, "Backup condiviso oltre il limite.")
        try require(Self.hash(try Data(contentsOf: url)) == head.sha256, "Backup condiviso incompleto o alterato.")
        return url
    }
    private func remember() throws { try JSONEncoder().encode(State(folder: folder.path, head: String(decoding: baseline, as: UTF8.self), fingerprint: fingerprint())).write(to: stateURL, options: .atomic) }
    func open(initialize: Bool = false) throws {
        try require(!reserved && FileManager.default.fileExists(atPath: folder.path), "Disco non raggiungibile oppure sessione già aperta. Collega la VPN e monta il disco.")
        try require(password.count >= 12, "Usa una password condivisa di almeno 12 caratteri.")
        let fd = Darwin.open(lease.path, O_WRONLY | O_CREAT | O_EXCL, 0o600)
        try require(fd >= 0, "Disco occupato da un’altra postazione o non scrivibile. Dopo un arresto anomalo verifica tutte le postazioni prima di rimuovere la prenotazione.")
        let bytes = Array(token.utf8)
        let written = bytes.withUnsafeBytes { Darwin.write(fd, $0.baseAddress, $0.count) }
        let flushed = fsync(fd); Darwin.close(fd)
        guard written == bytes.count && flushed == 0 else { throw AppIssue(message: "Prenotazione incompleta: verifica il collegamento e il file .dentallab-session.") }
        reserved = true
        do {
            baseline = try readHead()
            let previous = FileManager.default.fileExists(atPath: stateURL.path) ? try JSONDecoder().decode(State.self, from: Data(contentsOf: stateURL)) : nil
            let known = previous?.folder == folder.path
            try require(known || initialize, "Configura prima questa postazione: il primo collegamento richiede una conferma esplicita.")
            if known && previous!.head != String(decoding: baseline, as: UTF8.self) {
                try require(try previous!.fingerprint == fingerprint(), "Conflitto: modifiche locali e una nuova versione sul disco. Conserva un backup locale prima di risolverlo.")
            }
            if !baseline.isEmpty {
                let url = try backup(baseline); _ = try Vault.restore(Data(contentsOf: url), password: password)
                if !known || previous!.head != String(decoding: baseline, as: UTF8.self) { try own(); try restore(url, password); try remember() }
            } else {
                try require(!known || previous!.head.isEmpty, "La versione condivisa è scomparsa. Nessuna reinizializzazione automatica.")
                try publish()
            }
        } catch { try? release(); throw error }
    }
    func publish() throws {
        try own(); let revision = UUID().uuidString
        let target = folder.appendingPathComponent(revision + ".dlbackup")
        try export(target, password); let data = try Data(contentsOf: target); _ = try Vault.restore(data, password: password); try own()
        let head = try JSONEncoder().encode(Head(revision: revision, sha256: Self.hash(data)))
        try head.write(to: headURL, options: .atomic); baseline = head; try remember()
    }
    func finish() throws { try publish(); try release() }
    func release() throws {
        guard reserved else { return }
        try require(try String(contentsOf: lease, encoding: .utf8) == token, "Prenotazione cambiata: rilascio annullato.")
        try FileManager.default.removeItem(at: lease); reserved = false
    }
    static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    static func fingerprint(_ database: Database) throws -> String {
        var clone = database; clone.audit = []; clone.dailyAccess = nil; clone.calendarLink = nil; clone.fileGeneration = nil
        return try Vault.digest(clone)
    }
}
