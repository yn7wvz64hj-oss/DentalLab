import Foundation
import CryptoKit

struct BackupChecks {
    static func run() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("DentalLab-backup-checks-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let key = SymmetricKey(size: .bits256)
        let password = "Password-test-1234"
        var work = Entry(section: "Lavori"); work.name = "Corona sintetica"; work.patient = "Paziente sintetico"
        work.device = Device(); work.device?.toothWorks = [ToothWork(tooth: 11, kind: "Corona in zirconia", shadeSystem: "VITA classical A1–D4", shade: "A2")]
        let file = Attachment(name: "prescrizione.txt", category: "Prescrizione"); work.files = [file]
        let bytes = Data("Prescrizione sintetica · àèìòù".utf8)
        var database = Database(); database.entries = [work]; database.counters = ["FT-2026": 4]
        // Encrypted v2 source is preserved byte-for-byte during SQLite migration.
        let encrypted = try Vault.seal(JSONEncoder().encode(database), key: key)
        try encrypted.write(to: folder.appendingPathComponent("archivio.dlvault"))
        print("CHECK · migrazione archivio cifrato")
        var store: Store? = Store(folder: folder, testKey: key)
        try require(store!.ready, store!.error)
        try store!.saveBlob(bytes, id: file.id)
        try require(try Data(contentsOf: folder.appendingPathComponent("archivio.dlvault")) == encrypted, "La migrazione ha modificato l’archivio originale.")
        let competing = Store(folder: folder, testKey: key)
        try require(!competing.ready, "Seconda istanza ammessa sullo stesso archivio.")
        let backup = folder.appendingPathComponent("swift.dlbackup")
        print("CHECK · esportazione e manifesto")
        try store!.backup(password: password, to: backup)
        let payload = try store!.verifyBackup(password: password, from: backup)
        try require(payload.version == 2 && payload.fileHashes?.count == 1, "Manifesto non esportato.")
        let before = try Vault.digest(store!.db)
        var rejected = false
        do { try store!.restore(password: "sbagliata", from: backup) } catch { rejected = true }
        try require(rejected && (try Vault.digest(store!.db)) == before, "Dati cambiati dopo password errata.")
        print("CHECK · ripristino e identità allegati")
        try store!.restore(password: password, from: backup)
        try require(store!.entries[0].files?[0].id == file.id && (try store!.blob(file.id)) == bytes, "Identità allegato persa.")
        let rescues = try FileManager.default.contentsOfDirectory(at: folder.appendingPathComponent("PrimaDelRipristino"), includingPropertiesForKeys: nil)
        try require(rescues.count == 1 && FileManager.default.fileExists(atPath: rescues[0].appendingPathComponent("FileCifrati").appendingPathComponent(file.id.uuidString).path), "Copia preventiva incompleta.")
        print("CHECK · riavvio SQLite")
        store = nil
        store = Store(folder: folder, testKey: key)
        try require(store!.ready && (try store!.blob(file.id)) == bytes, "Generazione allegati persa al riavvio.")
        if let output = ProcessInfo.processInfo.environment["DENTALLAB_FIXTURE_OUTPUT"] {
            let destination = URL(fileURLWithPath: output); try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            try Data(contentsOf: backup).write(to: destination.appendingPathComponent("swift.dlbackup"))
        }
        if let input = ProcessInfo.processInfo.environment["DENTALLAB_FIXTURE_INPUT"] {
            print("CHECK · importazione backup Windows")
            let windows = try Vault.restore(Data(contentsOf: URL(fileURLWithPath: input).appendingPathComponent("windows.dlbackup")), password: password)
            try require(windows.database.entries.contains { $0.device?.toothWorks?.first?.shade == "A2" } && !windows.files.isEmpty, "Backup Windows non compatibile.")
            let imported = folder.appendingPathComponent("windows-import.dlbackup")
            try Data(contentsOf: URL(fileURLWithPath: input).appendingPathComponent("windows.dlbackup")).write(to: imported)
            try store!.restore(password: password, from: imported)
            for attachment in store!.entries.flatMap({ $0.files ?? [] }) { try require(try store!.blob(attachment.id) == windows.files[attachment.id.uuidString], "Allegato Windows non ripristinato.") }
        }
        print("PASS · migrazione SQLite, originali preservati, blocco istanza, manifesti, copia preventiva, identità allegati e riavvio")
    }
}
