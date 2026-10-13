import Foundation
import CryptoKit

struct SharedArchiveChecks {
    static func run() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Shared-check-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let remote = root.appendingPathComponent("shared"); try FileManager.default.createDirectory(at: remote, withIntermediateDirectories: true)
        let key = SymmetricKey(size: .bits256), password = "Password-test-1234"
        let a = Store(folder: root.appendingPathComponent("a"), testKey: key), b = Store(folder: root.appendingPathComponent("b"), testKey: key)
        func session(_ local: Store, secret: String = "Password-test-1234", location: URL? = nil) -> SharedArchiveSession {
            SharedArchiveSession(folder: location ?? remote, stateURL: local.folder.appendingPathComponent("sync-state.json"), password: secret, fingerprint: { try SharedArchiveSession.fingerprint(local.db) }, export: { url, pw in try local.backup(password: pw, to: url) }, restore: { url, pw in try local.restore(password: pw, from: url) })
        }
        func rejects(_ operation: () throws -> Void) throws { var refused = false; do { try operation() } catch { refused = true }; try require(refused,"Operazione condivisa non sicura accettata.") }
        let first = session(a); try first.open(initialize: true)
        try rejects { try session(b).open(initialize: true) }
        var next = a.db; next.profile.name = "Versione A"; try a.persist(next); try first.finish()
        let second = session(b); try second.open(initialize: true)
        try require(b.db.profile.name == "Versione A", "Importazione condivisa fallita.")
        try require(FileManager.default.fileExists(atPath: b.folder.appendingPathComponent("PrimaDelRipristino").path), "Copia preventiva assente.")
        next = b.db; next.profile.name = "Versione B"; try b.persist(next); try second.finish()
        let resumed = session(a); try resumed.open(); try require(a.db.profile.name == "Versione B","Aggiornamento tra postazioni fallito."); try resumed.finish()
        try rejects { try session(b, secret: "Password-errata-123").open() }
        next = b.db; next.profile.name = "Offline"; try b.persist(next)
        let writer = session(a); try writer.open(); try writer.finish()
        let head = remote.appendingPathComponent("dentallab-head.json"), original = try Data(contentsOf: head)
        try rejects { try session(b).open() }
        try require(b.db.profile.name == "Offline" && (try Data(contentsOf: head)) == original, "Conflitto ha sovrascritto dati.")
        let env = ProcessInfo.processInfo.environment
        if let input = env["DENTALLAB_FIXTURE_INPUT"], FileManager.default.fileExists(atPath: URL(fileURLWithPath: input).appendingPathComponent("shared").path) {
            let incoming = root.appendingPathComponent("incoming")
            try FileManager.default.copyItem(at: URL(fileURLWithPath: input).appendingPathComponent("shared"), to: incoming)
            let c = Store(folder: root.appendingPathComponent("cross"), testKey: key)
            let cross = session(c, location: incoming); try cross.open(initialize: true)
            try require(c.db.profile.name == "Versione B", "Manifesto e backup condivisi Windows non importati.")
            var crossDB = c.db; crossDB.profile.name = "Cross Swift"; try c.persist(crossDB); try cross.finish()
            if let output = env["DENTALLAB_FIXTURE_OUTPUT"] {
                let target = URL(fileURLWithPath: output).appendingPathComponent("shared")
                try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
                let current = try Data(contentsOf: incoming.appendingPathComponent("dentallab-head.json"))
                let manifest = try JSONDecoder().decode(SharedArchiveSession.Head.self, from: current)
                try current.write(to: target.appendingPathComponent("dentallab-head.json"))
                try FileManager.default.copyItem(at: incoming.appendingPathComponent(manifest.revision + ".dlbackup"), to: target.appendingPathComponent(manifest.revision + ".dlbackup"))
            }
        }
        try FileManager.default.removeItem(at: head); try rejects { try session(a).open() }
        print("PASS · disco condiviso: sessione esclusiva, passaggio, copia preventiva, password, conflitto e manifesto scomparso")
    }
}
