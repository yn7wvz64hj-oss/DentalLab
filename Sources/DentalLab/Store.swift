import SwiftUI
import AppKit
import CryptoKit
import LocalAuthentication
import Darwin

let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("DentalLab")
final class Store: ObservableObject {
    @Published var db = Database()
    @Published var error = ""
    @Published var notice = ""
    @Published var locked = false
    @Published var ready = false
    lazy var calendarBridge = CalendarBridge()
    let folder: URL
    private var key: SymmetricKey?
    private var lockFD: Int32 = -1
    private var ownsLock = false
    var entries: [Entry] { db.entries }
    init(folder: URL = root, testKey: SymmetricKey? = nil) {
        self.folder = folder
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            lockFD = Darwin.open(folder.appendingPathComponent(".lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
            try require(lockFD >= 0 && flock(lockFD, LOCK_EX | LOCK_NB) == 0, "L’archivio è già aperto in un’altra istanza di DentalLab.")
            ownsLock = true
            let file = folder.appendingPathComponent("archivio.dlvault")
            key = try testKey ?? Vault.localKey(create: !FileManager.default.fileExists(atPath: file.path))
            if FileManager.default.fileExists(atPath: file.path) { db = try JSONDecoder().decode(Database.self, from: Vault.open(Data(contentsOf: file), key: key!)); try require(db.version == 2, "Versione dell’archivio non supportata.") }
            else if FileManager.default.fileExists(atPath: folder.appendingPathComponent("archivio.json").path) {
                db.entries = try JSONDecoder().decode([Entry].self, from: Data(contentsOf: folder.appendingPathComponent("archivio.json")))
                for i in db.entries.indices {
                    var files: [Attachment] = []
                    for old in db.entries[i].attachments {
                        try require(URL(fileURLWithPath: old).lastPathComponent == old, "Nome allegato precedente non valido.")
                        let file = Attachment(name: old.components(separatedBy: "__").last ?? old)
                        try saveBlob(Data(contentsOf: folder.appendingPathComponent("Allegati").appendingPathComponent(old)), id: file.id)
                        files.append(file)
                    }
                    db.entries[i].files = files; db.entries[i].attachments = []
                }
                db.audit.append(Audit(action: "Migrazione", recordID: nil, label: "Archivio della prima versione importato. Copie precedenti in chiaro conservate per recupero."))
                try persist(db, backup: false)
                notice = "Archivio precedente importato. Le vecchie copie JSON e gli allegati in chiaro sono ancora presenti: verifica il backup prima di rimuoverle."
            } else { db.profile.regime = "RF01"; try persist(db, backup: false) }
            ready = true
        } catch { self.error = error.localizedDescription }
    }
    deinit { if lockFD >= 0 { flock(lockFD, LOCK_UN); Darwin.close(lockFD) } }
    func persist(_ next: Database, backup: Bool = true) throws {
        guard let key = key else { throw AppIssue(message: "Archivio bloccato: chiave non disponibile.") }
        let file = folder.appendingPathComponent("archivio.dlvault")
        let data = try Vault.seal(JSONEncoder().encode(next), key: key)
        if backup && FileManager.default.fileExists(atPath: file.path) {
            let path = folder.appendingPathComponent("BackupLocali"); try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
            let name = String(Int(Date().timeIntervalSince1970 * 1000)) + "-" + UUID().uuidString.prefix(6)
            try FileManager.default.copyItem(at: file, to: path.appendingPathComponent(String(name) + ".dlvault"))
            let files = try FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: nil).sorted { $0.lastPathComponent > $1.lastPathComponent }
            for old in files.dropFirst(60) { try FileManager.default.removeItem(at: old) }
        }
        try data.write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        db = next
    }
    func commit(_ label: String, recordID: UUID? = nil, update: (inout Database) throws -> Void) -> Bool {
        guard ready && !locked else { error = "Archivio non disponibile o bloccato."; return false }
        do { var next = db; try update(&next); next.audit.append(Audit(action: label, recordID: recordID, label: label)); try persist(next); if label != "Scadenze aggiornate nel calendario" && db.calendarLink?.automatic == true { calendarBridge.queue(self) }; return true } catch { self.error = error.localizedDescription; return false }
    }
    func save(_ value: Entry) -> Bool {
        var e = value; e.updated = Date(); if e.created == nil { e.created = Date() }
        return commit("Salvataggio · \(e.section) · \(e.name)", recordID: e.id) { next in
            try Validation.basic(e)
            if let old = next.entries.first(where: { $0.id == e.id }) {
                try require(old.issued == nil && !old.isArchived, "Il documento registrato o archiviato è bloccato. Crea una nuova bozza o una nota di credito.")
                if old.section == "Magazzino" { try require(old.available == e.available, "Varia la disponibilità attraverso un movimento di magazzino.") }
            }
            if e.section == "Magazzino" { try require(!e.available.isNaN && e.available >= 0 && (e.minimum ?? 0) >= 0, "Quantità o scorta minima non valide.") }
            if let i = next.entries.firstIndex(where: { $0.id == e.id }) { next.entries[i] = e } else { next.entries.append(e) }
        }
    }
    func archive(_ e: Entry) { _ = commit("Archiviazione · \(e.name)", recordID: e.id) { next in guard let i = next.entries.firstIndex(where: { $0.id == e.id }) else { return }; next.entries[i].archived = true } }
    func outstanding(_ e: Entry) -> Decimal {
        let credited = entries.filter { $0.issued != nil && $0.invoiceType == "TD04" && $0.relatedInvoiceID == e.id }.reduce(Decimal(0)) { $0 + $1.total }
        return max(0, e.total - e.received - credited)
    }
    func customer(_ e: Entry) -> Entry? { entries.first { $0.id == e.clientID && $0.section == "Clienti" } }
    func create(_ section: String, from source: Entry? = nil) -> Entry {
        var e = Entry(section: section); e.created = Date()
        if let source = source { e.name = source.name; e.client = source.client; e.clientID = source.clientID; e.patient = source.patient; e.workID = source.section == "Lavori" ? source.id : source.workID; e.device = source.device; e.files = source.files; e.lot = source.lot; e.detail = source.detail; e.lines = source.lines; e.price = source.price }
        if section == "Lavori" && e.device == nil { e.device = Device(); e.device?.identifier = "DL-" + String(e.id.uuidString.prefix(8)).uppercased() }
        if section == "Consegne" { e.delivery = Delivery() }
        if section == "Conformità" && e.device == nil { e.device = Device() }
        if section == "Clienti" { e.contact = Contact() }
        if section == "Qualità" || section == "Sorveglianza" { e.quality = Quality(); if section == "Sorveglianza" { e.quality?.kind = "Reclamo" }; e.status = "Aperto" }
        return e
    }
    func record(_ e: Entry) -> Bool {
        commit("Registrazione documento · \(e.section)", recordID: e.id) { next in
            try Validation.basic(e); try require(!e.isArchived && next.entries.first(where: { $0.id == e.id })?.issued == nil && documentSections.contains(e.section) && e.issued == nil, "Documento già registrato o non registrabile.")
            var value = e
            value.frozenMaterials = Documents.materialText(e, db: next)
            for f in e.files ?? [] { _ = try blob(f.id) }
            let customer = next.entries.first { $0.id == e.clientID && $0.section == "Clienti" }
            if e.section == "Conformità" { let missing = Validation.mdr(e, profile: next.profile); try require(missing.isEmpty, "Completa il fascicolo:\n" + missing.joined(separator: "\n")) }
            else { try require(customer != nil, "Seleziona un cliente dall’anagrafica."); try require(!next.profile.name.isEmpty, "Inserisci i dati del laboratorio nelle Impostazioni.") }
            if e.section == "Consegne" { let d = e.delivery ?? Delivery(); try require(!d.recipient.isEmpty && !d.address.isEmpty && !d.reason.isEmpty && d.packages > 0 && !e.items.isEmpty, "Completa destinatario, indirizzo, causale, colli e righe del documento di consegna.") }
            if e.section == "Preventivi" { try require(!e.items.isEmpty, "Aggiungi almeno una riga al preventivo.") }
            if e.section == "Fatture" {
                if e.invoiceType == "TD04" {
                    guard let original = next.entries.first(where: { $0.id == e.relatedInvoiceID && $0.section == "Fatture" && $0.issued != nil && $0.invoiceType != "TD04" }) else { throw AppIssue(message: "Collega la nota di credito a una fattura registrata.") }
                    try require(original.clientID == e.clientID && e.date >= Calendar.current.startOfDay(for: original.date), "La nota deve avere lo stesso cliente e una data non precedente alla fattura.")
                    let credited = next.entries.filter { $0.issued != nil && $0.relatedInvoiceID == original.id && $0.invoiceType == "TD04" }.reduce(Decimal(0)) { $0 + $1.total }
                    try require(e.total > 0 && e.total <= original.total - credited, "L’importo della nota supera il residuo rettificabile della fattura.")
                    value.relatedInvoiceNumber = original.label; value.relatedInvoiceDate = original.date
                }
                let missing = InvoiceXML.issues(value, profile: next.profile, customer: customer); try require(missing.isEmpty, missing.joined(separator: "\n"))
            }
            let year = Calendar(identifier: .gregorian).component(.year, from: e.date)
            let prefix = ["Fatture": e.invoiceType == "TD04" ? "NC" : "FT", "Preventivi": "PR", "Consegne": "DDT", "Conformità": "DSM"][e.section] ?? "DOC"
            let counter = "\(prefix)-\(year)"; let number = (next.counters[counter] ?? 0) + 1
            next.counters[counter] = number
            let code = "\(prefix)-\(year)-\(String(format: "%04d", number))"
            value.issued = Issued(number: code, date: Date(), profile: next.profile, customerName: customer?.name ?? e.client, customer: customer?.contact ?? Contact(), digest: "")
            let digest = try Vault.digest(value)
            value.issued?.digest = digest
            value.updated = Date()
            if let i = next.entries.firstIndex(where: { $0.id == e.id }) { next.entries[i] = value } else { next.entries.append(value) }
        }
    }
    func addPayment(_ payment: Payment, to entryID: UUID) -> Bool {
        commit("Incasso registrato", recordID: entryID) { next in
            guard let i = next.entries.firstIndex(where: { $0.id == entryID }) else { throw AppIssue(message: "Fattura non trovata.") }
            try require(payment.amount > 0 && !payment.amount.isNaN && payment.amount <= outstanding(next.entries[i]), "Importo non valido o superiore al saldo.")
            var p = next.entries[i].payments ?? []; p.append(payment); next.entries[i].payments = p; next.entries[i].paid = outstanding(next.entries[i]) == 0
        }
    }
    func updateSDI(_ entryID: UUID, status: String, reference: String) -> Bool {
        commit("Esito SDI annotato · \(status)", recordID: entryID) { next in guard let i = next.entries.firstIndex(where: { $0.id == entryID }) else { return }; try require(!reference.isEmpty, "Inserisci il riferimento della ricevuta SDI."); next.entries[i].sdiStatus = status; next.entries[i].sdiReference = reference }
    }
    func move(stockID: UUID, workID: UUID?, delta: Decimal, reason: String) -> Bool {
        commit("Movimento magazzino · \(reason)", recordID: stockID) { next in
            guard let i = next.entries.firstIndex(where: { $0.id == stockID && $0.section == "Magazzino" }) else { throw AppIssue(message: "Materiale non trovato.") }
            try require(!delta.isNaN && delta != 0 && !reason.isEmpty, "Inserisci quantità e causale.")
            let quantity = next.entries[i].available + delta; try require(quantity >= 0, "Scorta insufficiente: il movimento porterebbe il lotto sotto zero.")
            if let workID = workID { try require(delta < 0 && next.entries.contains { $0.id == workID && $0.section == "Lavori" && !$0.isArchived }, "Seleziona un lavoro attivo per il consumo."); try require(next.entries[i].expiry == nil || next.entries[i].expiry! >= Calendar.current.startOfDay(for: Date()), "Il lotto è scaduto.") }
            next.entries[i].stock = quantity
            next.movements.append(StockMovement(stockID: stockID, workID: workID, delta: delta, reason: reason))
            if let workID = workID, let wi = next.entries.firstIndex(where: { $0.id == workID }) { var uses = next.entries[wi].materialUses ?? []; uses.append(MaterialUse(stockID: stockID, quantity: -delta)); next.entries[wi].materialUses = uses }
        }
    }
    func saveBlob(_ data: Data, id: UUID) throws { guard let key = key else { throw AppIssue(message: "Chiave non disponibile.") }; let path = folder.appendingPathComponent("FileCifrati"); try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true); try Vault.seal(data, key: key).write(to: path.appendingPathComponent(id.uuidString), options: .atomic) }
    func attach(_ url: URL, category: String) throws -> Attachment { let data = try Data(contentsOf: url); try require(data.count <= 100 * 1024 * 1024, "Il limite per un allegato è 100 MB."); let f = Attachment(name: url.lastPathComponent, category: category); try saveBlob(data, id: f.id); return f }
    func blob(_ id: UUID) throws -> Data { guard let key = key else { throw AppIssue(message: "Chiave non disponibile.") }; return try Vault.open(Data(contentsOf: folder.appendingPathComponent("FileCifrati").appendingPathComponent(id.uuidString)), key: key) }
    func exportAttachment(_ f: Attachment) { let panel = NSSavePanel(); panel.nameFieldStringValue = f.name; if panel.runModal() == .OK, let url = panel.url { do { try blob(f.id).write(to: url, options: .atomic); notice = "Allegato esportato. La copia scelta non è cifrata dall’app." } catch { self.error = error.localizedDescription } } }
    func backup(password: String, to url: URL) throws {
        try require(ready && !locked, "Archivio non disponibile."); var files: [String: Data] = [:]; var size = 0
        for f in db.entries.flatMap({ $0.files ?? [] }) where files[f.id.uuidString] == nil { let data = try blob(f.id); size += data.count; try require(size <= 500 * 1024 * 1024, "Backup portabile oltre 500 MB: riduci gli allegati o pianifica un archivio più grande."); files[f.id.uuidString] = data }
        try Vault.portable(PortableBackup(database: db, files: files), password: password).write(to: url, options: .atomic)
        notice = "Backup completo cifrato esportato. Conserva la password separatamente."
    }
    func restore(password: String, from url: URL) throws {
        try require(ownsLock && !locked, "L’archivio è bloccato o aperto in un’altra istanza.")
        let payload = try Vault.restore(Data(contentsOf: url), password: password)
        if key == nil { key = try Vault.localKey(create: true) }
        // New attachment identifiers keep the previous archive intact if restoration fails.
        var mapping: [String: UUID] = [:]
        for (name, data) in payload.files { try require(UUID(uuidString: name) != nil, "Identificativo allegato non valido."); let id = UUID(); try saveBlob(data, id: id); mapping[name] = id }
        var next = payload.database
        next.calendarLink = nil
        for (series, value) in db.counters { next.counters[series] = max(next.counters[series] ?? 0, value) }
        for i in next.entries.indices { if var files = next.entries[i].files { for j in files.indices { guard let id = mapping[files[j].id.uuidString] else { throw AppIssue(message: "Allegato mancante.") }; files[j].id = id }; next.entries[i].files = files } }
        next.audit.append(Audit(action: "Ripristino", recordID: nil, label: "Backup completo ripristinato")); try persist(next); ready = true; error = ""; notice = "Backup ripristinato."
    }

    func lock() { let context = LAContext(); var err: NSError?; if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) { locked = true } else { error = "Autenticazione macOS non disponibile: usa il blocco schermo del Mac." } }
    func unlock() { let context = LAContext(); context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Aprire l’archivio del laboratorio") { success, err in DispatchQueue.main.async { if success { self.locked = false } else { self.error = err?.localizedDescription ?? "Autenticazione non riuscita." } } } }
}
