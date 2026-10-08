import Foundation

func roundMoney(_ value: Decimal) -> Decimal { var x = value; var result = Decimal(); NSDecimalRound(&result, &x, 2, .plain); return result }
func money(_ value: Decimal) -> String { let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "EUR"; f.locale = Locale(identifier: "it_IT"); return f.string(from: value as NSDecimalNumber) ?? "€ 0,00" }
func numeric(_ value: Decimal) -> String { NSDecimalNumber(decimal: value).stringValue }
func day(_ date: Date) -> String { let f = DateFormatter(); f.locale = Locale(identifier: "it_IT"); f.dateStyle = .medium; return f.string(from: date) }
func isoDay(_ date: Date) -> String { let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(identifier: "Europe/Rome"); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date) }
let workStates = ["Da iniziare", "In lavorazione", "In prova", "Pronto", "Consegnato"]
let sections = ["Panoramica", "Lavori", "Scadenze", "Clienti", "Listino", "Preventivi", "Consegne", "Fatture", "Magazzino", "Conformità", "Qualità", "Sorveglianza", "Attività", "Impostazioni"]
let documentSections = ["Preventivi", "Consegne", "Fatture", "Conformità"]
struct Contact: Codable, Equatable {
    var vat = ""; var taxCode = ""; var address = ""; var zip = ""; var city = ""; var province = ""; var email = ""; var phone = ""; var recipient = "0000000"; var pec = ""
    var addressText: String { [address, zip + " " + city, province].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.joined(separator: ", ") }
}
struct Profile: Codable, Equatable {
    var name = ""; var contact = Contact(); var productionSites = ""; var representative = "Non applicabile"; var registration = ""; var prrc = ""; var iban = ""; var regime = "Da verificare"; var privacyProcedure = ""; var qualityProcedure = ""
}
struct Line: Codable, Identifiable, Equatable {
    var id = UUID(); var title = ""; var quantity: Decimal = 1; var unitPrice: Decimal = 0; var discount: Decimal = 0; var vat: Decimal = 0; var nature = ""; var taxReference = ""
    var net: Decimal { roundMoney(quantity * unitPrice * (1 - discount / 100)) }
}
struct Payment: Codable, Identifiable, Equatable { var id = UUID(); var date = Date(); var amount: Decimal = 0; var method = "Bonifico"; var reference = "" }
struct MaterialUse: Codable, Identifiable, Equatable { var id = UUID(); var stockID: UUID; var quantity: Decimal = 1 }
struct Device: Codable, Equatable {
    var toothWorks: [ToothWork]?
    var dentalElements: String { guard let works = toothWorks else { return teeth }; return works.map { $0.tooth }.sorted().map(String.init).joined(separator: ", ") }
    var dentalShades: String { guard let works = toothWorks else { return shade }; return Array(Set(works.map { $0.shadeSystem + " " + $0.shade })).sorted().joined(separator: "; ") }
    var identifier = ""; var type = "Protesi fissa"; var riskClass = "Da valutare"; var implantable = false; var prescriber = ""; var institution = ""; var prescription = ""; var prescriptionDate = Date(); var teeth = ""; var shade = ""; var intendedUse = ""; var design = ""; var manufacturing = ""; var performance = ""; var risks = ""; var requirements = ""; var exceptions = ""; var substances = "Da valutare"; var instructions = ""; var checks = ""; var reviewer = ""; var conformityConfirmed = false; var releaseDate = Date()
}
struct Delivery: Codable, Equatable { var recipient = ""; var address = ""; var carrier = ""; var reason = "Consegna dispositivo su misura"; var packages = 1; var transportDate = Date() }
struct Quality: Codable, Equatable { var kind = "Non conformità"; var cause = ""; var action = ""; var result = ""; var owner = ""; var severity = "Da valutare"; var authorityReference = "" }
struct StockMovement: Codable, Identifiable { var id = UUID(); var date = Date(); var stockID: UUID; var workID: UUID?; var delta: Decimal; var reason: String }
struct Audit: Codable, Identifiable { var id = UUID(); var date = Date(); var action: String; var recordID: UUID?; var label: String }
struct Attachment: Codable, Identifiable, Equatable { var id = UUID(); var name: String; var category = "Generale" }
struct Issued: Codable, Equatable { var number: String; var date: Date; var profile: Profile; var customerName: String; var customer: Contact; var digest: String }
struct Entry: Codable, Identifiable, Equatable {
    var id = UUID(); var section: String; var name = ""; var client = ""; var patient = ""; var detail = ""; var status = "Da iniziare"; var date = Date(); var price = 0.0; var quantity = 0.0; var lot = ""; var paid = false; var attachments: [String] = []
    // Optional additions allow the first version's archive to be decoded without losing fields.
    var delivery: Delivery?; var frozenMaterials: String?; var relatedInvoiceID: UUID?; var relatedInvoiceNumber: String?; var relatedInvoiceDate: Date?; var contact: Contact?; var device: Device?; var lines: [Line]?; var payments: [Payment]?; var materialUses: [MaterialUse]?; var files: [Attachment]?; var quality: Quality?; var clientID: UUID?; var workID: UUID?; var issued: Issued?; var archived: Bool?; var created: Date?; var updated: Date?; var unit: String?; var supplier: String?; var expiry: Date?; var minimum: Decimal?; var stock: Decimal?; var stamp: Decimal?; var invoiceType: String?; var paymentMethod: String?; var paymentDue: Date?; var sdiStatus: String?; var sdiReference: String?
    var isArchived: Bool { archived ?? false }
    var items: [Line] { lines ?? [] }
    var net: Decimal { items.isEmpty ? roundMoney(Decimal(price)) : items.reduce(0) { $0 + $1.net } }
    var tax: Decimal { taxGroups.reduce(0) { $0 + $1.tax } }
    var total: Decimal { net + tax + (stamp ?? 0) }
    var received: Decimal { payments == nil && paid ? total : (payments ?? []).reduce(0) { $0 + $1.amount } }
    var balance: Decimal { max(0, total - received) }
    var available: Decimal { stock ?? Decimal(quantity) }
    var label: String { issued?.number ?? (name.isEmpty ? "Senza titolo" : name) }
    var taxGroups: [TaxGroup] {
        var values: [String: TaxGroup] = [:]
        for line in items { let key = numeric(line.vat) + "|" + line.nature + "|" + line.taxReference; var g = values[key] ?? TaxGroup(vat: line.vat, nature: line.nature, reference: line.taxReference, net: 0); g.net += line.net; values[key] = g }
        return values.keys.sorted().compactMap { values[$0] }
    }
}
struct TaxGroup { var vat: Decimal; var nature: String; var reference: String; var net: Decimal; var tax: Decimal { roundMoney(net * vat / 100) } }
struct Database: Codable { var dailyAccess: DailyAccess?; var calendarLink: CalendarLink?; var version = 2; var entries: [Entry] = []; var profile = Profile(); var movements: [StockMovement] = []; var audit: [Audit] = []; var counters: [String: Int] = [:] }
struct PortableBackup: Codable { var version = 1; var database: Database; var files: [String: Data] }
struct AppIssue: LocalizedError { var message: String; var errorDescription: String? { message } }
func require(_ condition: Bool, _ message: String) throws { if !condition { throw AppIssue(message: message) } }
struct Validation {
    static func basic(_ e: Entry) throws {
        try require(!e.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Inserisci un titolo o riferimento.")
        try require(e.price.isFinite && e.price >= 0 && e.quantity.isFinite && e.quantity >= 0, "Importi e quantità devono essere validi e non negativi.")
        for l in e.items { try require(!l.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !l.quantity.isNaN && l.quantity > 0 && !l.unitPrice.isNaN && l.unitPrice >= 0 && l.discount >= 0 && l.discount <= 100 && l.vat >= 0 && l.vat <= 100, "Controlla descrizione, quantità, prezzo, sconto e IVA delle righe.") }
        if let works = e.device?.toothWorks {
            try require(Set(works.map { $0.tooth }).count == works.count, "Un dente compare più volte nella mappa.")
            for work in works {
                try require(DentalSelection.valid.contains(work.tooth) && !work.kind.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !work.shade.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Controlla numero del dente, lavorazione e colore.")
                if work.shadeSystem == "VITA classical A1–D4" { try require(DentalSelection.shades.contains(work.shade), "Codice VITA classical non valido.") }
            }
        }
        for p in e.payments ?? [] { try require(!p.amount.isNaN && p.amount > 0, "Ogni pagamento deve avere un importo positivo.") }
        try require((e.stamp ?? 0) >= 0 && !(e.stamp ?? 0).isNaN, "Il bollo non può essere negativo.")
        try require(e.received <= e.total, "Gli incassi superano il totale del documento.")
    }
    static func contact(_ c: Contact, name: String) -> [String] {
        var missing: [String] = []
        if name.isEmpty { missing.append("ragione sociale") }
        if c.address.isEmpty || c.city.isEmpty || c.zip.count != 5 || !c.zip.allSatisfy(\.isNumber) || c.province.count != 2 { missing.append("indirizzo italiano completo (CAP e provincia)") }
        if !validVAT(c.vat) { missing.append("partita IVA italiana valida") }
        return missing
    }
    static func validVAT(_ raw: String) -> Bool {
        let s = raw.replacingOccurrences(of: "IT", with: "").trimmingCharacters(in: .whitespaces)
        guard s.count == 11, s.allSatisfy({ $0.isASCII && $0.isNumber }) else { return false }
        let a = s.compactMap { $0.wholeNumberValue }; var sum = 0
        for i in 0..<10 { let x = a[i] * (i % 2 == 0 ? 1 : 2); sum += x > 9 ? x - 9 : x }
        return s != "00000000000" && (10 - sum % 10) % 10 == a[10]
    }
    static func mdr(_ e: Entry, profile: Profile) -> [String] {
        let d = e.device ?? Device(); var m: [String] = []
        if profile.name.isEmpty || profile.contact.addressText.isEmpty || profile.productionSites.isEmpty { m.append("Fabbricante, indirizzo e luoghi di fabbricazione") }
        if profile.representative.isEmpty { m.append("Mandatario o indicazione Non applicabile") }
        if d.identifier.isEmpty { m.append("Identificativo univoco del dispositivo") }
        if e.patient.isEmpty { m.append("Paziente: nome, acronimo o codice") }
        if d.prescriber.isEmpty { m.append("Prescrittore autorizzato") }
        if d.prescription.isEmpty { m.append("Caratteristiche specifiche della prescrizione") }
        if !(e.files ?? []).contains(where: { $0.category == "Prescrizione" }) { m.append("Prescrizione allegata al fascicolo") }
        if d.requirements.isEmpty || !d.conformityConfirmed { m.append("Verifica dei requisiti di sicurezza e prestazione") }
        if d.substances == "Da valutare" { m.append("Valutazione di sostanze medicinali e tessuti/cellule") }
        if d.design.isEmpty || d.manufacturing.isEmpty || d.performance.isEmpty || d.risks.isEmpty { m.append("Progettazione, fabbricazione, prestazioni e rischi documentati") }
        if d.checks.isEmpty || d.instructions.isEmpty || d.reviewer.isEmpty { m.append("Controlli, istruzioni e responsabile della verifica") }
        if d.riskClass == "Da valutare" { m.append("Classificazione del dispositivo") }
        if d.implantable && d.riskClass == "III" { m.append("Classe III impiantabile: procedura aggiuntiva con organismo notificato non gestita da questa versione") }
        return m
    }
}
