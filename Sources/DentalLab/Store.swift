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
    @Published var needsPasswordSetup = false
    private var failedAccess = 0
    private var retryAfter = Date.distantPast
    private let usesDailyGate: Bool
    lazy var calendarBridge = CalendarBridge()
    let folder: URL
    private var key: SymmetricKey?
    private var lockFD: Int32 = -1
    private var ownsLock = false
    private var sqlite: SQLiteArchive?
    @Published var sharedSession: SharedArchiveSession?
    @Published var editedDrafts: Set<UUID> = []
    var sharedConfig: URL { folder.appendingPathComponent("sync-folder.txt") }
    var sharedRequired: Bool { FileManager.default.fileExists(atPath: sharedConfig.path) }
    func connectShared(folder remote: URL, password: String, initialize: Bool) throws {
        try require(ready && !locked && sharedSession == nil, "Sblocca l’archivio e chiudi eventuali sessioni precedenti.")
        let session = SharedArchiveSession(folder: remote, stateURL: folder.appendingPathComponent("sync-state.json"), password: password, fingerprint: { [unowned self] in try SharedArchiveSession.fingerprint(self.db) }, export: { [unowned self] url, secret in try self.backup(password: secret, to: url, allowLocked: true) }, restore: { [unowned self] url, secret in try self.restore(password: secret, from: url) })
        // Export during the first connection is already protected by the local access gate.
        sharedSession = session
        do { try session.open(initialize: initialize); try remote.path.write(to: sharedConfig, atomically: true, encoding: .utf8); notice = "Disco collegato. Chiudi DentalLab prima di passare all’altra postazione." }
        catch { try? session.release(); sharedSession = nil; throw error }
    }
    func finishShared() throws { if let session = sharedSession { try session.finish(); sharedSession = nil } }
    var entries: [Entry] { db.entries }
    init(folder: URL = root, testKey: SymmetricKey? = nil) {
        self.folder = folder
        usesDailyGate = testKey == nil
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            lockFD = Darwin.open(folder.appendingPathComponent(".lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
            try require(lockFD >= 0 && flock(lockFD, LOCK_EX | LOCK_NB) == 0, "L’archivio è già aperto in un’altra istanza di DentalLab.")
            ownsLock = true
            let file = folder.appendingPathComponent("archivio.dlvault")
            let sqliteURL = folder.appendingPathComponent("archivio.sqlite")
            let existingSQLite = FileManager.default.fileExists(atPath: sqliteURL.path)
            key = try testKey ?? Vault.localKey(create: !existingSQLite && !FileManager.default.fileExists(atPath: file.path))
            if existingSQLite {
                sqlite = try SQLiteArchive(url: sqliteURL, create: false)
                db = try JSONDecoder().decode(Database.self, from: Vault.open(sqlite!.read(), key: key!))
                try require(db.version == 2, "Versione dell’archivio non supportata.")
            } else {
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
            // The encrypted legacy source remains untouched and recoverable.
            sqlite = try SQLiteArchive.install(Vault.seal(JSONEncoder().encode(db), key: key!), at: sqliteURL)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: sqliteURL.path)
            }
            ready = true
            if usesDailyGate { refreshDailyLock() }
        } catch { self.error = error.localizedDescription }
    }
    deinit { if lockFD >= 0 { flock(lockFD, LOCK_UN); Darwin.close(lockFD) } }
    func persist(_ next: Database, backup: Bool = true) throws {
        guard let key = key else { throw AppIssue(message: "Archivio bloccato: chiave non disponibile.") }
        let file = folder.appendingPathComponent("archivio.dlvault")
        let data = try Vault.seal(JSONEncoder().encode(next), key: key)
        if let sqlite = sqlite {
            try sqlite.write(data, history: backup)
            db = next
            return
        }
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
        guard ready && !locked && (!sharedRequired || sharedSession != nil) else { error = "Archivio non disponibile o bloccato."; return false }
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
    func conformity(for work: Entry, forceNew: Bool = false) -> Entry? {
        guard work.section == "Lavori" else { error = "Seleziona una scheda lavoro."; return nil }
        if !forceNew, let existing = entries.filter({ $0.section == "Conformità" && $0.workID == work.id && !$0.isArchived }).sorted(by: { ($0.updated ?? $0.created ?? $0.date) > ($1.updated ?? $1.created ?? $1.date) }).first { return existing }
        var document = create("Conformità", from: work); document.name = "Conformità · " + work.name
        guard save(document) else { return nil }; return entries.first { $0.id == document.id }
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
    private func blobFolder(_ database: Database) throws -> URL {
        let path = folder.appendingPathComponent("FileCifrati")
        guard let generation = database.fileGeneration else { return path }
        try require(UUID(uuidString: generation)?.uuidString == generation, "Generazione allegati non valida.")
        return path.appendingPathComponent(generation)
    }
    func saveBlob(_ data: Data, id: UUID) throws { guard let key = key else { throw AppIssue(message: "Chiave non disponibile.") }; let path = try blobFolder(db); try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true); try Vault.seal(data, key: key).write(to: path.appendingPathComponent(id.uuidString), options: .atomic) }
    func attach(_ url: URL, category: String) throws -> Attachment { let data = try Data(contentsOf: url); try require(data.count <= 100 * 1024 * 1024, "Il limite per un allegato è 100 MB."); let f = Attachment(name: url.lastPathComponent, category: category); try saveBlob(data, id: f.id); return f }
    func blob(_ id: UUID) throws -> Data { guard let key = key else { throw AppIssue(message: "Chiave non disponibile.") }; return try Vault.open(Data(contentsOf: blobFolder(db).appendingPathComponent(id.uuidString)), key: key) }
    func exportAttachment(_ f: Attachment) { let panel = NSSavePanel(); panel.nameFieldStringValue = f.name; if panel.runModal() == .OK, let url = panel.url { do { try blob(f.id).write(to: url, options: .atomic); notice = "Allegato esportato. La copia scelta non è cifrata dall’app." } catch { self.error = error.localizedDescription } } }
    func backup(password: String, to url: URL, allowLocked: Bool = false) throws {
        try require(ready && (!locked || (allowLocked && sharedSession != nil)), "Archivio non disponibile."); var files: [String: Data] = [:]; var size = 0
        for f in db.entries.flatMap({ $0.files ?? [] }) where files[f.id.uuidString] == nil { let data = try blob(f.id); size += data.count; try require(size <= 500 * 1024 * 1024, "Backup portabile oltre 500 MB: riduci gli allegati o pianifica un archivio più grande."); files[f.id.uuidString] = data }
        try sqlite?.verify()
        var portableDatabase = db; portableDatabase.fileGeneration = nil
        let data = try Vault.portable(PortableBackup(database: portableDatabase, files: files), password: password)
        _ = try Vault.restore(data, password: password)
        try data.write(to: url, options: .atomic)
        _ = try verifyBackup(password: password, from: url)
        notice = "Backup completo cifrato esportato. Conserva la password separatamente."
    }
    @discardableResult
    func verifyBackup(password: String, from url: URL) throws -> PortableBackup {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        try require(size > 52 && size <= 750 * 1024 * 1024, "Dimensione backup non valida o superiore a 750 MB.")
        return try Vault.restore(Data(contentsOf: url), password: password)
    }
    func restore(password: String, from url: URL) throws {
        try require(ownsLock && !locked, "L’archivio è bloccato o aperto in un’altra istanza.")
        let payload = try verifyBackup(password: password, from: url)
        // Complete encrypted rescue copy, including attachments, before any mutation.
        let rescue = folder.appendingPathComponent("PrimaDelRipristino").appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: rescue, withIntermediateDirectories: true)
        for name in ["archivio.sqlite", "archivio.dlvault", "archivio.json", "FileCifrati", "Allegati"] {
            let source = folder.appendingPathComponent(name)
            if name == "archivio.sqlite", let sqlite = sqlite { try sqlite.snapshot(to: rescue.appendingPathComponent(name)) }
            else if FileManager.default.fileExists(atPath: source.path) { try FileManager.default.copyItem(at: source, to: rescue.appendingPathComponent(name)) }
        }
        let generation = UUID().uuidString
        let staged = folder.appendingPathComponent("FileCifrati").appendingPathComponent(generation)
        var completed = false
        defer { if !completed { try? FileManager.default.removeItem(at: …9405 tokens truncated…bject().Clear(); Reject(() => BackupCodec.Validate(missing), "Allegato mancante accettato");
    var duplicate = (JsonObject)decoded.DeepClone(); duplicate["database"]!["entries"]!.AsArray().Add(duplicate["database"]!["entries"]![0]!.DeepClone()); Reject(() => BackupCodec.Validate(duplicate), "Scheda duplicata accettata");
    var manifest = (JsonObject)decoded.DeepClone(); manifest["fileHashes"]![fileID] = "errato"; Reject(() => BackupCodec.Validate(manifest), "Hash errato accettato");
    var unsafeName = (JsonObject)decoded.DeepClone(); unsafeName["files"]!["../file"] = ""; Reject(() => BackupCodec.Validate(unsafeName), "Percorso non valido accettato");
    var legacy = (JsonObject)decoded.DeepClone(); legacy["version"] = 1; legacy.Remove("fileHashes"); byte[] salt = RandomNumberGenerator.GetBytes(16); byte[] old = "DLBACK02"u8.ToArray().Concat(salt).Concat(BackupCodec.Seal(Encoding.UTF8.GetBytes(legacy.ToJsonString()), BackupCodec.Derive(password, salt))).ToArray(); Check(BackupCodec.Decode(old, password)["version"]!.GetValue<int>() == 1, "Backup v1 non supportato");
    string folder = Path.Combine(root, "local"), backup = Path.Combine(root, "test.dlbackup");
    using (var archive = new LocalArchive(folder, key)) {
        archive.SaveBlob(fileID, file); archive.Save(db); archive.Export(backup, password);
        Check(!Encoding.UTF8.GetString(ReadShared(Path.Combine(folder, "archivio.sqlite"))).Contains("Paziente sintetico"), "Database in chiaro");
        Reject(() => { using var competing = new LocalArchive(folder, key); }, "Seconda istanza accettata");
        var future = (JsonObject)archive.Database.DeepClone(); future["counters"]!["FT-2026"] = 20; archive.Save(future);
        string rescue = archive.Restore(backup, password);
        Check(File.Exists(Path.Combine(rescue, "archivio.sqlite")) && File.Exists(Path.Combine(rescue, "FileCifrati", fileID)), "Copia preventiva incompleta");
        Check(archive.Database["counters"]!["FT-2026"]!.GetValue<int>() == 20, "Contatore abbassato");
        string newID = archive.Database["entries"]![1]!["files"]![0]!["id"]!.GetValue<string>(); Check(newID == fileID && archive.Blob(newID).SequenceEqual(file), "Ripristino allegati e identità");
        JsonObject before = (JsonObject)archive.Database.DeepClone(); Reject(() => archive.Restore(backup, "sbagliata"), "Ripristino con password errata"); Check(JsonNode.DeepEquals(before, archive.Database), "Archivio cambiato dopo errore");
        for (int i = 0; i < 70; i++) archive.Save(archive.Database);
        using var sql = new SqliteConnection($"Data Source={Path.Combine(folder, "archivio.sqlite")};Pooling=False"); sql.Open(); using var command = sql.CreateCommand(); command.CommandText = "SELECT COUNT(*) FROM revisions"; Check((long)command.ExecuteScalar()! == 60, "Storico non limitato a 60");
    }
    using (var reopened = new LocalArchive(folder, key)) { Check(reopened.Database["entries"]!.AsArray().Count == 2, "Persistenza dopo riavvio"); reopened.VerifySQLite(); }
    foreach (string point in new[] { "after-rescue", "after-attachment", "before-commit" }) {
        bool inject = false;
        using var target = new LocalArchive(Path.Combine(root, point), key) { FailureInjection = p => { if (inject && p == point) throw new IOException("Interruzione simulata"); } };
        var before = (JsonObject)target.Database.DeepClone(); inject = true;
        Reject(() => target.Restore(backup, password), "Interruzione non intercettata: " + point);
        Check(JsonNode.DeepEquals(before, target.Database), "Dati persi: " + point);
        string blobFolder = Path.Combine(target.Folder, "FileCifrati"); Check(!Directory.Exists(blobFolder) || Directory.GetFiles(blobFolder,"*",SearchOption.AllDirectories).Length == 0, "Allegati parziali: " + point);
        inject = false; target.VerifySQLite();
    }
    string badFolder = Path.Combine(root, "bad"); Directory.CreateDirectory(badFolder); byte[] corruption = "corrotto"u8.ToArray(); File.WriteAllBytes(Path.Combine(badFolder, "archivio.sqlite"), corruption);
    Reject(() => { using var badArchive = new LocalArchive(badFolder, key); }, "Archivio corrotto accettato"); Check(File.ReadAllBytes(Path.Combine(badFolder, "archivio.sqlite")).SequenceEqual(corruption), "Archivio corrotto sovrascritto");
    if (OperatingSystem.IsWindows()) {
        string dpapiFolder = Path.Combine(root, "dpapi"); using (var a = new LocalArchive(dpapiFolder)) { a.Save(db); }
        using (var a = new LocalArchive(dpapiFolder)) Check(JsonNode.DeepEquals(a.Database, db), "DPAPI dopo riavvio");
        File.Delete(Path.Combine(dpapiFolder, "local.key")); byte[] original = File.ReadAllBytes(Path.Combine(dpapiFolder, "archivio.sqlite"));
        Reject(() => { using var a = new LocalArchive(dpapiFolder); }, "Chiave mancante ricreata"); Check(File.ReadAllBytes(Path.Combine(dpapiFolder, "archivio.sqlite")).SequenceEqual(original), "Archivio senza chiave sovrascritto");
    }
    string? fixtureOutput = Environment.GetEnvironmentVariable("DENTALLAB_FIXTURE_OUTPUT");
    if (fixtureOutput != null) { Directory.CreateDirectory(fixtureOutput); File.WriteAllBytes(Path.Combine(fixtureOutput, "windows.dlbackup"), encoded); }
    string? fixtureInput = Environment.GetEnvironmentVariable("DENTALLAB_FIXTURE_INPUT");
    if (fixtureInput != null) {
        var swift = BackupCodec.Decode(File.ReadAllBytes(Path.Combine(fixtureInput, "swift.dlbackup")), password);
        Check(swift["database"]!["entries"]!.AsArray().Any(e => e?["device"]?["toothWorks"]?.AsArray().Any(t => t?["shade"]?.GetValue<string>() == "A2") == true), "Odontogramma Swift non letto");
        Check(swift["files"]!.AsObject().Count > 0, "Allegati Swift non letti");
    }
    checks += SharedArchiveChecks.Run(root, key, password);
    checks += ConformityChecks.Run(root,key);
    Console.WriteLine($"PASS · {checks} verifiche: backup, compatibilità, SQLite, cifratura, blocco istanza, DPAPI e rollback.");
} finally { SqliteConnection.ClearAllPools(); Directory.Delete(root, true); CryptographicOperations.ZeroMemory(key); }
