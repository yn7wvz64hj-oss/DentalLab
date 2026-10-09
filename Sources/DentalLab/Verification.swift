import AppKit
import SwiftUI
import CryptoKit
import PDFKit

struct SelfTests {
    static func run() throws {
        try BackupChecks.run()
        try DentalChartChecks.run()
        var deadlineWork = Entry(section: "Lavori"); deadlineWork.name = "Nome clinico da non inviare"; deadlineWork.patient = "Paziente riservato"
        deadlineWork.date = ISO8601DateFormatter().date(from: "2026-03-29T12:00:00Z")!
        let planned = Deadline.make([deadlineWork, Entry(section: "Clienti")])
        try require(planned.count == 1 && planned[0].end.timeIntervalSince(planned[0].start) == 23 * 3600, "Consegna o cambio ora legale errati")
        try require(!planned[0].title.contains(deadlineWork.name) && !planned[0].title.contains(deadlineWork.patient), "Dettagli clinici nel calendario")
        deadlineWork.status = "Consegnato"
        try require(Deadline.make([deadlineWork]).isEmpty, "Consegna completata ancora pianificata")
        deadlineWork.status = "In lavorazione"; deadlineWork.archived = true
        try require(Deadline.make([deadlineWork]).isEmpty, "Lavoro archiviato ancora pianificato")
        let oldData = try JSONEncoder().encode(Database())
        let oldDatabase = try JSONDecoder().decode(Database.self, from: oldData)
        try require(oldDatabase.calendarLink == nil, "Migrazione calendario errata")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("DentalLab-tests-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let key = SymmetricKey(size: .bits256)
        try AccessChecks.run(folder: folder.appendingPathComponent("access"), key: key)
        let store = Store(folder: folder, testKey: key)
        try require(store.ready, store.error)
        var line = Line(); line.title = "Lavorazione di prova"; line.unitPrice = Decimal(string: "12.345")!; line.quantity = 3; line.discount = 10; line.vat = 22
        var invoice = Entry(section: "Fatture"); invoice.name = "Prova"; invoice.lines = [line]
        try require(invoice.net == Decimal(string: "33.33")! && invoice.tax == Decimal(string: "7.33")! && invoice.total == Decimal(string: "40.66")!, "Arrotondamenti di riga/IVA errati")
        try require(Validation.validVAT("12345678903") && !Validation.validVAT("12345678900"), "Controllo P.IVA errato")
        var profile = Profile(); profile.name = "Laboratorio di prova"; profile.regime = "RF01"; profile.contact.vat = "12345678903"; profile.contact.address = "Via Prova 1"; profile.contact.zip = "00100"; profile.contact.city = "Roma"; profile.contact.province = "RM"; profile.productionSites = "Via Prova 1, Roma"
        try require(store.commit("Configurazione test", update: { $0.profile = profile }), store.error)
        var customer = store.create("Clienti"); customer.name = "Studio di prova"; customer.contact = profile.contact
        try require(store.save(customer), store.error)
        invoice.clientID = customer.id; invoice.client = customer.name
        try require(store.record(invoice), store.error)
        guard let registered = store.entries.first(where: { $0.id == invoice.id }) else { throw AppIssue(message: "Documento non salvato") }
        try require(registered.label.hasSuffix("0001"), "Numerazione errata")
        let xml = try InvoiceXML.xml(registered); let parsed = try XMLDocument(xmlString: xml, options: [])
        try require(try parsed.nodes(forXPath: "//PrezzoUnitario").first?.stringValue == "12.345", "Precisione prezzo persa in XML")
        var changed = registered; changed.detail = "modificato"; try require(!store.save(changed), "Documento registrato modificabile"); store.error = ""
        try require(!store.record(registered), "Documento numerato due volte"); store.error = ""
        try require(!store.record(invoice), "Bozza obsoleta ha sovrascritto il documento registrato"); store.error = ""
        var second = invoice; second.id = UUID(); second.name = "Seconda"; try require(store.record(second), store.error)
        try require(store.entries.first(where: { $0.id == second.id })?.label.hasSuffix("0002") == true, "Progressivo non incrementato")
        var payment = Payment(); payment.amount = 10; try require(store.addPayment(payment, to: invoice.id), store.error)
        payment.amount = 100; try require(!store.addPayment(payment, to: invoice.id), "Incasso superiore al saldo accettato"); store.error = ""
        var stock = store.create("Magazzino"); stock.name = "Materiale"; stock.lot = "LOT-01"; stock.stock = 5; try require(store.save(stock), store.error)
        var work = store.create("Lavori"); work.name = "Lavoro prova"; try require(store.save(work), store.error)
        try require(store.move(stockID: stock.id, workID: work.id, delta: -2, reason: "Consumo"), store.error)
        try require(store.entries.first(where: { $0.id == stock.id })?.available == 3, "Quantità magazzino errata")
        try require(store.entries.first(where: { $0.id == work.id })?.materialUses?.count == 1, "Consumo non collegato al lavoro")
        try require(!store.move(stockID: stock.id, workID: nil, delta: -10, reason: "Scarico"), "Magazzino negativo accettato"); store.error = ""
        var credit = store.create("Fatture", from: registered); credit.name = "Nota di credito prova"; credit.invoiceType = "TD04"; credit.relatedInvoiceID = invoice.id; credit.detail = "Rettifica parziale"; credit.lines = [Line(title: "Rettifica", quantity: 1, unitPrice: 5, discount: 0, vat: 22)]
        try require(store.record(credit), store.error)
        let registeredCredit = store.entries.first { $0.id == credit.id }!
        let creditXML = try XMLDocument(xmlString: InvoiceXML.xml(registeredCredit), options: [])
        try require(try creditXML.nodes(forXPath: "//DatiFattureCollegate/IdDocumento").first?.stringValue == registered.label, "Nota di credito senza riferimento fattura")
        try require(store.outstanding(store.entries.first { $0.id == invoice.id }!) == Decimal(string: "24.56")!, "Nota di credito non sottratta dal saldo")
        var incompleteDelivery = store.create("Consegne", from: work); incompleteDelivery.name = "Consegna"; try require(!store.record(incompleteDelivery), "Consegna incompleta registrata"); store.error = ""
        var declaration = store.create("Conformità", from: work); declaration.name = "Dichiarazione incompleta"; try require(!store.record(declaration), "Dichiarazione incompleta registrata"); store.error = ""
        let attachmentURL = folder.appendingPathComponent("prescrizione-test.txt"); try Data("Allegato di prova".utf8).write(to: attachmentURL)
        let attachment = try store.attach(attachmentURL, category: "Prescrizione"); work.files = [attachment]; try require(store.save(work), store.error)
        let encrypted = try Data(contentsOf: folder.appendingPathComponent("archivio.sqlite")); try require(String(data: encrypted, encoding: .utf8)?.contains("Studio di prova") != true, "Archivio in chiaro")
        let backup = folder.appendingPathComponent("test.dlbackup"); try store.backup(password: "Password-test-1234", to: backup)
        let backupData = try Data(contentsOf: backup)
        var wrongRejected = false; do { _ = try Vault.restore(backupData, password: "sbagliata") } catch { wrongRejected = true }; try require(wrongRejected, "Password errata accettata")
        var broken = backupData; broken[broken.count - 1] ^= 1
        var tamperRejected = false; do { _ = try Vault.restore(broken, password: "Password-test-1234") } catch { tamperRejected = true }; try require(tamperRejected, "Backup alterato accettato")
        let seriesKey = "FT-\(Calendar.current.component(.year, from: invoice.date))"
        try require(store.commit("Contatore futuro", update: { $0.counters[seriesKey] = 20 }), store.error)
        try store.restore(password: "Password-test-1234", from: backup)
        try require(store.db.counters[seriesKey] == 20, "Il ripristino ha abbassato il progressivo")
        let restored = store.entries.first { $0.id == work.id }!.files!.first!
        try require(try store.blob(restored.id) == Data("Allegato di prova".utf8), "Allegato non recuperato")
        let pdfURL = folder.appendingPathComponent("multipagina.pdf"); var long = work; long.detail = String(repeating: "Testo di verifica del documento, con dettagli del lavoro e istruzioni.\n", count: 200)
        try Documents.pdf(long, db: store.db, to: pdfURL)
        let pdf = CGPDFDocument(pdfURL as CFURL); try require((pdf?.numberOfPages ?? 0) > 2 && pdf?.page(at: 1) != nil, "PDF multipagina incompleto")
        if let target = ProcessInfo.processInfo.environment["DENTALLAB_TEST_OUTPUT"] { let out = URL(fileURLWithPath: target); try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true); try FileManager.default.copyItem(at: pdfURL, to: out.appendingPathComponent("multipagina.pdf")); try Documents.pdf(declaration, db: store.db, to: out.appendingPathComponent("dichiarazione-bozza.pdf")); for name in ["multipagina", "dichiarazione-bozza"] { if let doc = PDFDocument(url: out.appendingPathComponent(name + ".pdf")), let page = doc.page(at: 0) { let image = page.thumbnail(of: NSSize(width: 900, height: 1273), for: .mediaBox); if let data = image.tiffRepresentation, let rep = NSBitmapImageRep(data: data), let png = rep.representation(using: .png, properties: [:]) { try png.write(to: out.appendingPathComponent(name + ".png")) } } } }
        let payload = try Vault.restore(backupData, password: "Password-test-1234")
        try require(payload.database.entries.count == store.entries.count, "Schede perse nel backup")
        let badFolder = folder.appendingPathComponent("Corrotto"); try FileManager.default.createDirectory(at: badFolder, withIntermediateDirectories: true); let corrupted = Data("archivio corrotto".utf8); let corruptedURL = badFolder.appendingPathComponent("archivio.dlvault"); try corrupted.write(to: corruptedURL)
        let badStore = Store(folder: badFolder, testKey: key); try require(!badStore.ready && (try Data(contentsOf: corruptedURL)) == corrupted, "Archivio corrotto sovrascritto")
        let legacyFolder = folder.appendingPathComponent("Legacy"); try FileManager.default.createDirectory(at: legacyFolder, withIntermediateDirectories: true); var legacy = Entry(section: "Clienti"); legacy.name = "Cliente precedente"; try JSONEncoder().encode([legacy]).write(to: legacyFolder.appendingPathComponent("archivio.json")); let migrated = Store(folder: legacyFolder, testKey: key); try require(migrated.ready && migrated.entries.first?.name == legacy.name, "Migrazione archivio precedente fallita")
        print("PASS · conti decimali, IVA, P.IVA, XML, numerazione, documenti bloccati, incassi, scorte, tracciabilità, MDR, DDT, note di credito, cifratura, backup/password/integrità, ripristino allegati, archivio corrotto, migrazione e PDF multipagina")
    }
}
struct PreviewRenderer {
    static func run(to path: String) {
        let app = NSApplication.shared; app.setActivationPolicy(.accessory)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("DentalLab-preview-" + UUID().uuidString)
        let store = Store(folder: folder, testKey: SymmetricKey(size: .bits256))
        var profile = Profile(); profile.name = "Studio Forma"; profile.regime = "RF01"; store.db.profile = profile
        for (i, title) in ["Corona in zirconia", "Bite notturno", "Protesi mobile", "Ponte su tre elementi", "Riparazione protesi"].enumerated() { var e = store.create("Lavori"); e.name = title; e.client = ["Studio Rossi", "Studio Bianchi", "Studio Verdi"][i % 3]; e.status = workStates[i % 4]; e.date = Calendar.current.date(byAdding: .day, value: i - 1, to: Date())!; store.db.entries.append(e) }
        var invoice = Entry(section: "Fatture"); invoice.name = "Fattura di esempio"; invoice.price = 1280; store.db.entries.append(invoice)
        if ProcessInfo.processInfo.environment["DENTALLAB_PREVIEW_TAB"] == "Mappa dentale" { store.db.entries[0].device?.toothWorks = [ToothWork(tooth: 11, kind: "Corona in zirconia", shadeSystem: "VITA classical A1–D4", shade: "A2"), ToothWork(tooth: 21, kind: "Corona in zirconia", shadeSystem: "VITA classical A1–D4", shade: "A2"), ToothWork(tooth: 16, kind: "Intarsio", shadeSystem: "VITA classical A1–D4", shade: "A3")] }
        let module = ProcessInfo.processInfo.environment["DENTALLAB_PREVIEW_MODULE"] ?? "Panoramica"
        if module == "Accesso" { store.refreshDailyLock() }
        if module == "Lavori" { var old = store.entries[0]; old.id = UUID(); old.name = "Lavoro dell’anno precedente"; old.date = Calendar.current.date(byAdding: .year, value: -1, to: Date())!; store.db.entries.append(old) }
        let isEditor = module == "Editor"
        let width: CGFloat = isEditor ? 990 : 1440
        let height: CGFloat = isEditor ? 770 : 960
        let tab = ProcessInfo.processInfo.environment["DENTALLAB_PREVIEW_TAB"] ?? "Scheda"
        let content: AnyView = isEditor ? AnyView(Editor(entry: store.entries[0], initialTab: tab).environmentObject(store)) : AnyView(ContentView(section: module).environmentObject(store))
        let view = content.frame(width: width, height: height).tint(Palette.teal).labelStyle(.titleAndIcon).buttonStyle(LabButtonStyle()).preferredColorScheme(.light)
        let host = NSHostingView(rootView: view); host.frame = NSRect(x: 0, y: 0, width: width, height: height)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false); window.contentView = host; window.orderFront(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            host.layoutSubtreeIfNeeded()
            if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) { host.cacheDisplay(in: host.bounds, to: rep); if let data = rep.representation(using: .png, properties: [:]) { try? data.write(to: URL(fileURLWithPath: path)) } }
            window.close(); try? FileManager.default.removeItem(at: folder); exit(0)
        }
        app.run()
    }
}
