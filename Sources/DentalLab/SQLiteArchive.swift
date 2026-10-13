import Foundation
import CSQLite

// Encrypted Codable snapshots preserve all existing fields and document digests.
// SQL transactions provide an atomic current revision and bounded local history.
final class SQLiteArchive {
    private var connection: OpaquePointer?
    static func install(_ data: Data, at url: URL) throws -> SQLiteArchive {
        let temporary = url.deletingLastPathComponent().appendingPathComponent(".migration-" + UUID().uuidString + ".sqlite")
        defer { try? FileManager.default.removeItem(at: temporary) }
        var staged: SQLiteArchive? = try SQLiteArchive(url: temporary, create: true)
        try staged!.write(data, history: false)
        try staged!.verify()
        staged = nil
        // Closed DELETE-journal database: publish only after complete validation.
        try Data(contentsOf: temporary).write(to: url, options: .atomic)
        return try SQLiteArchive(url: url, create: false)
    }
    init(url: URL, create: Bool) throws {
        let flags = SQLITE_OPEN_READWRITE | (create ? SQLITE_OPEN_CREATE : 0)
        guard sqlite3_open_v2(url.path, &connection, flags, nil) == SQLITE_OK else {
            if connection != nil { sqlite3_close(connection); connection = nil }
            throw AppIssue(message: "Impossibile aprire l’archivio SQLite.")
        }
        do {
            sqlite3_busy_timeout(connection, 5000)
            try execute("PRAGMA synchronous=FULL")
            if create {
                try execute("CREATE TABLE archive (id INTEGER PRIMARY KEY CHECK(id=1), payload BLOB NOT NULL); CREATE TABLE revisions (id INTEGER PRIMARY KEY AUTOINCREMENT, payload BLOB NOT NULL); PRAGMA user_version=1")
            }
            try require(try scalar("PRAGMA user_version") == "1", "Versione SQLite non supportata.")
            try verify()
        } catch { sqlite3_close(connection); connection = nil; throw error }
    }
    deinit { sqlite3_close(connection) }
    private func execute(_ sql: String) throws {
        try require(sqlite3_exec(connection, sql, nil, nil, nil) == SQLITE_OK, "Operazione SQLite non riuscita.")
    }
    private func scalar(_ sql: String) throws -> String {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        try require(sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK && sqlite3_step(statement) == SQLITE_ROW, "Lettura SQLite non riuscita.")
        return String(cString: sqlite3_column_text(statement, 0))
    }
    func verify() throws { try require(try scalar("PRAGMA integrity_check") == "ok", "Archivio SQLite danneggiato: ripristina un backup.") }
    func snapshot(to url: URL) throws {
        var destination: OpaquePointer?
        try require(sqlite3_open_v2(url.path, &destination, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK, "Copia preventiva SQLite non disponibile.")
        defer { sqlite3_close(destination) }
        guard let backup = sqlite3_backup_init(destination, "main", connection, "main") else { throw AppIssue(message: "Copia preventiva SQLite non avviata.") }
        let status = sqlite3_backup_step(backup, -1)
        let finish = sqlite3_backup_finish(backup)
        try require(status == SQLITE_DONE && finish == SQLITE_OK, "Copia preventiva SQLite incompleta.")
    }
    func read() throws -> Data {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        try require(sqlite3_prepare_v2(connection, "SELECT payload FROM archive WHERE id=1", -1, &statement, nil) == SQLITE_OK && sqlite3_step(statement) == SQLITE_ROW, "Snapshot SQLite mancante.")
        let count = Int(sqlite3_column_bytes(statement, 0))
        guard let bytes = sqlite3_column_blob(statement, 0), count > 0 else { throw AppIssue(message: "Snapshot SQLite vuoto.") }
        return Data(bytes: bytes, count: count)
    }
    func write(_ data: Data, history: Bool) throws {
        try execute("BEGIN IMMEDIATE")
        do {
            if history { try execute("INSERT INTO revisions(payload) SELECT payload FROM archive WHERE id=1") }
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            try require(sqlite3_prepare_v2(connection, "INSERT OR REPLACE INTO archive(id,payload) VALUES(1,?)", -1, &statement, nil) == SQLITE_OK, "Scrittura SQLite non disponibile.")
            let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            try data.withUnsafeBytes { bytes in
                try require(sqlite3_bind_blob(statement, 1, bytes.baseAddress, Int32(data.count), transient) == SQLITE_OK && sqlite3_step(statement) == SQLITE_DONE, "Salvataggio SQLite non riuscito.")
            }
            try execute("DELETE FROM revisions WHERE id NOT IN (SELECT id FROM revisions ORDER BY id DESC LIMIT 60)")
            try execute("COMMIT")
        } catch { try? execute("ROLLBACK"); throw error }
    }
}
