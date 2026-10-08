import Foundation
import CryptoKit

struct AccessChecks {
    static func run(folder: URL, key: SymmetricKey) throws {
        let store = Store(folder: folder, testKey: key)
        let now = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        store.refreshDailyLock(now: now)
        try require(store.locked && store.needsPasswordSetup, "Prima configurazione non bloccata")
        try store.setDailyPassword("Password-prova-123", now: now)
        try require(!store.locked && !store.needsPasswordSetup, "Configurazione password fallita")
        store.refreshDailyLock(now: now)
        try require(!store.locked, "Secondo accesso dello stesso giorno bloccato")
        store.lock()
        try require(store.db.dailyAccess?.lastDay == nil, "Blocco manuale non persistito")
        var rejected = false
        do { try store.unlockWithPassword("errata", now: now) } catch { rejected = true }
        try require(rejected && store.locked, "Password errata accettata")
        var work = Entry(section: "Lavori"); work.name = "Test bloccato"
        try require(!store.save(work) && store.entries.isEmpty, "Salvataggio possibile mentre bloccato")
        store.error = ""
        try store.unlockWithPassword("Password-prova-123", now: now)
        store.refreshDailyLock(now: tomorrow)
        try require(store.locked, "Nuova giornata non bloccata")
        try store.unlockWithPassword("Password-prova-123", now: tomorrow)
        try store.changeDailyPassword(current: "Password-prova-123", new: "Nuova-password-456")
        store.lock()
        rejected = false
        do { try store.unlockWithPassword("Password-prova-123") } catch { rejected = true }
        try require(rejected && store.locked, "Vecchia password ancora accettata")
        try store.unlockWithPassword("Nuova-password-456")
        let disk = try JSONDecoder().decode(Database.self, from: Vault.open(Data(contentsOf: folder.appendingPathComponent("archivio.dlvault")), key: key))
        try require(try disk.dailyAccess!.accepts("Nuova-password-456"), "Password non persistita")
        var january = Entry(section: "Lavori"); january.date = ISO8601DateFormatter().date(from: "2026-12-31T23:30:00Z")!
        var previous = january; previous.id = UUID(); previous.archived = true; previous.date = ISO8601DateFormatter().date(from: "2025-06-01T12:00:00Z")!
        try require(WorkYear.of(january) == 2027 && WorkYear.available([january, previous, Entry(section: "Clienti")]) == [2027, 2025], "Suddivisione anni o fuso italiano errati")
        let one = try DailyAccess.make("Stessa-password-123"); let two = try DailyAccess.make("Stessa-password-123")
        try require(one.salt != two.salt && one.verifier != two.verifier, "Salt password riutilizzato")
        print("PASS · prima configurazione, accesso giornaliero, blocco manuale, password errata/cambio/persistenza, salvataggio bloccato e anni di consegna")
    }
}
