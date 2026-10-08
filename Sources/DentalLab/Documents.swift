import AppKit
import CoreGraphics
import Foundation
import UniformTypeIdentifiers

struct InvoiceXML {
    static let natures = ["N1", "N2.1", "N2.2", "N3.1", "N3.2", "N3.3", "N3.4", "N3.5", "N3.6", "N4", "N5", "N6.1", "N6.2", "N6.3", "N6.4", "N6.5", "N6.6", "N6.7", "N6.8", "N6.9", "N7"]
    static func issues(_ e: Entry, profile: Profile, customer: Entry?) -> [String] {
        var result = Validation.contact(profile.contact, name: profile.name).map { "Laboratorio: " + $0 }
        if !["TD01", "TD04"].contains(e.invoiceType ?? "TD01") { result.append("Tipo documento non supportato: TD01 o TD04.") }
        if !["MP01", "MP05", "MP08"].contains(e.paymentMethod ?? "MP05") { result.append("Modalità pagamento non supportata.") }
        if profile.regime != "RF01" { result.append("Questa versione gestisce XML B2B italiani in regime ordinario RF01.") }
        guard let customer = customer else { return result + ["Seleziona un cliente italiano con partita IVA."] }
        let c = customer.contact ?? Contact(); result += Validation.contact(c, name: customer.name).map { "Cliente: " + $0 }
        if c.recipient.count != 7 || !c.recipient.allSatisfy({ $0.isASCII && ($0.isNumber || $0.isUppercase) }) { result.append("Codice destinatario: 7 caratteri maiuscoli o numerici.") }
        if e.items.isEmpty { result.append("Inserisci almeno una riga di fattura.") }
        for l in e.items {
            if l.vat == 0 && (!natures.contains(l.nature) || l.taxReference.isEmpty) { result.append("\(l.title): per IVA zero indica natura e riferimento fiscale.") }
            if l.vat > 0 && !l.nature.isEmpty { result.append("\(l.title): una riga con IVA non deve avere un codice natura.") }
        }
        if e.patient.count > 0 { result.append("Rimuovi il riferimento al paziente dalla fattura: usa un riferimento interno al lavoro.") }
        if e.invoiceType == "TD04" && e.relatedInvoiceNumber == nil { result.append("Nota di credito: collega la fattura da rettificare.") }
        return Array(Set(result)).sorted()
    }
    static func xml(_ e: Entry) throws -> String {
        guard let issued = e.issued else { throw AppIssue(message: "Registra prima il documento per assegnare il numero.") }
        let p = issued.profile; let c = issued.customer
        var customer = Entry(section: "Clienti"); customer.name = issued.customerName; customer.contact = c
        try require(issues(e, profile: p, customer: customer).isEmpty, "Dati fiscali incompleti.")
        func esc(_ s: String) -> String { s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "'", with: "&apos;") }
        func tag(_ name: String, _ value: String) -> String { "<\(name)>\(esc(value))</\(name)>" }
        func amount(_ x: Decimal) -> String { let f = NumberFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.minimumFractionDigits = 2; f.maximumFractionDigits = 2; f.usesGroupingSeparator = false; return f.string(from: roundMoney(x) as NSDecimalNumber) ?? "0.00" }
        func vatID(_ raw: String) -> String { raw.replacingOccurrences(of: "IT", with: "").trimmingCharacters(in: .whitespaces) }
        func address(_ c: Contact) -> String { "<Sede>" + tag("Indirizzo", c.address) + tag("CAP", c.zip) + tag("Comune", c.city) + tag("Provincia", c.province.uppercased()) + "<Nazione>IT</Nazione></Sede>" }
        var s = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<p:FatturaElettronica xmlns:p=\"http://ivaservizi.agenziaentrate.gov.it/docs/xsd/fatture/v1.2\" versione=\"FPR12\">\n<FatturaElettronicaHeader><DatiTrasmissione><IdTrasmittente><IdPaese>IT</IdPaese>" + tag("IdCodice", vatID(p.contact.vat)) + "</IdTrasmittente>" + tag("ProgressivoInvio", String(e.id.uuidString.replacingOccurrences(of: "-", with: "").prefix(10))) + "<FormatoTrasmissione>FPR12</FormatoTrasmissione>" + tag("CodiceDestinatario", c.recipient)
        if c.recipient == "0000000" && !c.pec.isEmpty { s += tag("PECDestinatario", c.pec) }
        s += "</DatiTrasmissione><CedentePrestatore><DatiAnagrafici><IdFiscaleIVA><IdPaese>IT</IdPaese>" + tag("IdCodice", vatID(p.contact.vat)) + "</IdFiscaleIVA>"
        if !p.contact.taxCode.isEmpty { s += tag("CodiceFiscale", p.contact.taxCode) }
        s += "<Anagrafica>" + tag("Denominazione", p.name) + "</Anagrafica><RegimeFiscale>RF01</RegimeFiscale></DatiAnagrafici>" + address(p.contact) + "</CedentePrestatore><CessionarioCommittente><DatiAnagrafici><IdFiscaleIVA><IdPaese>IT</IdPaese>" + tag("IdCodice", vatID(c.vat)) + "</IdFiscaleIVA>"
        if !c.taxCode.isEmpty { s += tag("CodiceFiscale", c.taxCode) }
        s += "<Anagrafica>" + tag("Denominazione", issued.customerName) + "</Anagrafica></DatiAnagrafici>" + address(c) + "</CessionarioCommittente></FatturaElettronicaHeader>\n<FatturaElettronicaBody><DatiGenerali><DatiGeneraliDocumento>" + tag("TipoDocumento", e.invoiceType ?? "TD01") + "<Divisa>EUR</Divisa>" + tag("Data", isoDay(e.date)) + tag("Numero", issued.number)
        if (e.stamp ?? 0) > 0 { s += "<DatiBollo><BolloVirtuale>SI</BolloVirtuale>" + tag("ImportoBollo", amount(e.stamp ?? 0)) + "</DatiBollo>" }
        s += tag("ImportoTotaleDocumento", amount(e.total))
        if !e.detail.isEmpty { for start in stride(from: 0, to: e.detail.count, by: 190) { let chars = Array(e.detail); s += tag("Causale", String(chars[start..<min(start + 190, chars.count)])) } }
        s += "</DatiGeneraliDocumento>"
        if let number = e.relatedInvoiceNumber { s += "<DatiFattureCollegate>" + tag("IdDocumento", number); if let date = e.relatedInvoiceDate { s += tag("Data", isoDay(date)) }; s += "</DatiFattureCollegate>" }
        s += "</DatiGenerali><DatiBeniServizi>"
        for (i, l) in e.items.enumerated() {
            s += "<DettaglioLinee>" + tag("NumeroLinea", String(i + 1)) + tag("Descrizione", l.title) + tag("Quantita", numeric(l.quantity)) + tag("PrezzoUnitario", numeric(l.unitPrice))
            if l.discount > 0 { s += "<ScontoMaggiorazione><Tipo>SC</Tipo>" + tag("Percentuale", amount(l.discount)) + "</ScontoMaggiorazione>" }
            s += tag("PrezzoTotale", amount(l.net)) + tag("AliquotaIVA", amount(l.vat)); if l.vat == 0 { s += tag("Natura", l.nature) }; s += "</DettaglioLinee>"
        }
        for g in e.taxGroups { s += "<DatiRiepilogo>" + tag("AliquotaIVA", amount(g.vat)); if g.vat == 0 { s += tag("Natura", g.nature) }; s += tag("ImponibileImporto", amount(g.net)) + tag("Imposta", amount(g.tax)); if g.vat > 0 { s += "<EsigibilitaIVA>I</EsigibilitaIVA>" }; if !g.reference.isEmpty { s += tag("RiferimentoNormativo", g.reference) }; s += "</DatiRiepilogo>" }
        s += "</DatiBeniServizi>"
        if e.invoiceType != "TD04" { s += "<DatiPagamento><CondizioniPagamento>TP02</CondizioniPagamento><DettaglioPagamento>" + tag("ModalitaPagamento", e.paymentMethod ?? "MP05") + tag("DataScadenzaPagamento", isoDay(e.paymentDue ?? e.date)) + tag("ImportoPagamento", amount(e.total)); if !p.iban.isEmpty && (e.paymentMethod ?? "MP05") == "MP05" { s += tag("IBAN", p.iban.replacingOccurrences(of: " ", with: "")) }; s += "</DettaglioPagamento></DatiPagamento>" }
        s += "</FatturaElettronicaBody></p:FatturaElettronica>"
        _ = try XMLDocument(xmlString: s, options: [])
        return s
    }
}

struct PDFBlock { var title: String; var text: String }
struct Documents {
    static func blocks(_ e: Entry, db: Database) -> [PDFBlock] {
        let p = e.issued?.profile ?? db.profile
        let customer = e.issued?.customer ?? db.entries.first(where: { $0.id == e.clientID })?.contact ?? Contact()
        let customerName = e.issued?.customerName ?? db.entries.first(where: { $0.id == e.clientID })?.name ?? e.client
        var result = [PDFBlock(title: "Laboratorio", text: "\(p.name)\n\(p.contact.addressText)\nP.IVA \(p.contact.vat) · CF \(p.contact.taxCode)\n\(p.contact.email) · \(p.contact.phone)")]
        if e.section == "Conformità" {
            let d = e.device ?? Device()
            result += [PDFBlock(title: "Fabbricazione", text: "Luoghi: \(p.productionSites)\nMandatario: \(p.representative)\nRegistrazione fabbricante: \(p.registration)"), PDFBlock(title: "Identificazione e destinazione", text: "Dispositivo: \(d.identifier) · \(d.type)\nClasse dichiarata dal fabbricante: \(d.riskClass)\nUso esclusivo per il paziente/utilizzatore: \(e.patient)\nPrescrittore: \(d.prescriber)\nIstituzione sanitaria: \(d.institution)\nDestinazione d’uso: \(d.intendedUse)"), PDFBlock(title: "Prescrizione e caratteristiche specifiche", text: "Data prescrizione: \(day(d.prescriptionDate))\n\(d.prescription)\nElementi dentali: \(d.dentalElements) · Colore: \(d.dentalShades)"), PDFBlock(title: "Dichiarazione del fabbricante", text: "Il fabbricante dichiara che il dispositivo è destinato esclusivamente al paziente/utilizzatore sopra identificato. La verifica dei requisiti applicabili dell’Allegato I è documentata nei riferimenti seguenti:\n\(d.requirements)\nConformità confermata dal fabbricante: \(d.conformityConfirmed ? "Sì" : "Non confermata")\nRequisiti non interamente rispettati e motivazione: \(d.exceptions.isEmpty ? "Nessuna eccezione indicata dal fabbricante" : d.exceptions)\nSostanze medicinali, derivati del sangue e tessuti/cellule: \(d.substances)"), PDFBlock(title: "Controlli e tracciabilità", text: "\(d.checks)\nMateriali/lotti: \(materialText(e, db: db))\nResponsabile della verifica: \(d.reviewer)\nImmissione sul mercato dichiarata: \(day(d.releaseDate))\nConservare la dichiarazione almeno fino al: \(day(Calendar.current.date(byAdding: .year, value: d.implantable ? 15 : 10, to: d.releaseDate) ?? d.releaseDate))"), PDFBlock(title: "Istruzioni", text: d.instructions), PDFBlock(title: "Sottoscrizione", text: "Luogo e data: __________________________\nFirma del fabbricante: __________________________\nRiferimento: Regolamento (UE) 2017/745, Allegato XIII. La registrazione informatica non costituisce firma elettronica né certificazione di conformità.")]
        } else {
            result.append(PDFBlock(title: "Cliente", text: "\(customerName)\n\(customer.addressText)\nP.IVA \(customer.vat) · CF \(customer.taxCode)"))
            if e.section == "Consegne" { let d = e.delivery ?? Delivery(); result.append(PDFBlock(title: "Trasporto", text: "Destinatario: \(d.recipient)\nIndirizzo: \(d.address)\nData trasporto: \(day(d.transportDate))\nCausale: \(d.reason)\nVettore / a cura di: \(d.carrier)\nColli: \(d.packages)")) }
            if ["Lavori", "Conformità"].contains(e.section), let works = e.device?.toothWorks, !works.isEmpty { result.append(PDFBlock(title: "Lavorazioni per elemento dentale", text: DentalSelection.summary(works))) }
            if e.section == "Lavori" { let d = e.device ?? Device(); result.append(PDFBlock(title: "Dispositivo", text: "Codice paziente: \(e.patient)\n\(d.identifier) · \(d.type)\nStato: \(e.status)\nConsegna prevista: \(day(e.date))\nPrescrizione: \(d.prescription)\n\(d.dentalElements) · \(d.dentalShades)\nMateriali: \(materialText(e, db: db))")) }
            if !e.items.isEmpty { for (i, l) in e.items.enumerated() { result.append(PDFBlock(title: "\(i + 1). \(l.title)", text: e.section == "Consegne" ? "Quantità \(numeric(l.quantity))" : "Quantità \(numeric(l.quantity)) · Prezzo \(money(l.unitPrice)) · Sconto \(numeric(l.discount))%\nImponibile \(money(l.net)) · IVA \(numeric(l.vat))% \(l.nature)\n\(l.taxReference)")) } }
            if ["Fatture", "Preventivi", "Lavori", "Listino"].contains(e.section) { result.append(PDFBlock(title: "Riepilogo", text: "Imponibile: \(money(e.net))\nIVA: \(money(e.tax))\nBollo addebitato: \(money(e.stamp ?? 0))\nTotale: \(money(e.total))\nScadenza pagamento: \(day(e.paymentDue ?? e.date))")) }
            if e.section == "Fatture" { result.append(PDFBlock(title: "Documento fiscale", text: "Copia di cortesia. L’emissione fiscale richiede trasmissione al Sistema di Interscambio e gestione delle ricevute. Questo PDF e il backup dell’app non sostituiscono la conservazione elettronica a norma.")) }
            if !e.detail.isEmpty { result.append(PDFBlock(title: "Note", text: e.detail)) }
        }
        return result
    }
    static func materialText(_ e: Entry, db: Database) -> String {
        if let frozen = e.frozenMaterials { return frozen }
        let work = e.workID.flatMap { id in db.entries.first { $0.id == id } } ?? e
        let uses = (work.materialUses ?? []).map { use -> String in let stock = db.entries.first { $0.id == use.stockID }; return "\(stock?.name ?? "Materiale") · lotto \(stock?.lot ?? "") · \(numeric(use.quantity)) \(stock?.unit ?? "unità")" }
        return ([e.lot] + uses).filter { !$0.isEmpty }.joined(separator: "\n")
    }
    static func pdf(_ e: Entry, db: Database, to url: URL) throws {
        guard let consumer = CGDataConsumer(url: url as CFURL) else { throw AppIssue(message: "Impossibile creare il PDF.") }
        var media = CGRect(x: 0, y: 0, width: 595, height: 842)
        guard let ctx = CGContext(consumer: consumer, mediaBox: &media, nil) else { throw AppIssue(message: "PDF non disponibile.") }
        var page = 0; var y: CGFloat = 0
        let ink = NSColor(calibratedRed: 0.12, green: 0.19, blue: 0.28, alpha: 1)
        let accent = NSColor(calibratedRed: 0.05, green: 0.45, blue: 0.48, alpha: 1)
        func draw(_ text: String, x: CGFloat, top: CGFloat, width: CGFloat, font: NSFont, color: NSColor) {
            let paragraph = NSMutableParagraphStyle(); paragraph.lineBreakMode = .byWordWrapping
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
            let ns = text as NSString; let h = ns.boundingRect(with: NSSize(width: width, height: 2000), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs).height + 3
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
            ns.draw(with: NSRect(x: x, y: 842 - top - h, width: width, height: h), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs)
            NSGraphicsContext.restoreGraphicsState()
        }
        func start() {
            if page > 0 { ctx.endPDFPage() }; page += 1; ctx.beginPDFPage(nil)
            ctx.setFillColor(accent.cgColor); ctx.fill(CGRect(x: 0, y: 832, width: 595, height: 10))
            draw("DENTALLAB", x: 42, top: 28, width: 220, font: .systemFont(ofSize: 12, weight: .bold), color: accent)
            draw(e.section == "Conformità" ? "Dichiarazione per dispositivo su misura" : e.section, x: 42, top: 60, width: 511, font: .systemFont(ofSize: 22, weight: .semibold), color: ink)
            draw("\(String(e.label.prefix(75))) · \(day(e.date)) · \(e.issued == nil ? "BOZZA" : "REGISTRATO")", x: 42, top: 95, width: 511, font: .systemFont(ofSize: 10), color: .gray)
            draw("DentalLab · \(String(e.label.prefix(65)))", x: 42, top: 797, width: 390, font: .systemFont(ofSize: 9), color: .gray)
            draw("Pagina \(page)", x: 465, top: 797, width: 88, font: .systemFont(ofSize: 9), color: .gray)
            y = 134
        }
        func lines(_ raw: String, font: NSFont) -> [String] {
            var result: [String] = []
            for paragraph in raw.components(separatedBy: "\n") {
                var line = ""
                for word in paragraph.components(separatedBy: .whitespaces).filter({ !$0.isEmpty }) {
                    let trial = line.isEmpty ? word : line + " " + word
                    if (trial as NSString).size(withAttributes: [.font: font]).width <= 507 { line = trial; continue }
                    if !line.isEmpty { result.append(line); line = "" }
                    for char in word { let candidate = line + String(char); if (candidate as NSString).size(withAttributes: [.font: font]).width > 507 && !line.isEmpty { result.append(line); line = String(char) } else { line = candidate } }
                }
                result.append(line)
            }
            return result
        }
        start()
        for block in blocks(e, db: db) {
            if y > 717 { start() }
            let titleFont = NSFont.systemFont(ofSize: 12, weight: .semibold)
            for line in lines(block.title, font: titleFont) { if y > 751 { start() }; draw(line, x: 42, top: y, width: 511, font: titleFont, color: accent); y += 18 }
            y += 4
            for line in lines(block.text, font: .systemFont(ofSize: 11)) { if y > 751 { start() }; draw(line, x: 42, top: y, width: 511, font: .systemFont(ofSize: 11), color: ink); y += 16 }
            y += 18
        }
        ctx.endPDFPage(); ctx.closePDF()
    }
    static func exportPDF(_ e: Entry, db: Database, store: Store) { let panel = NSSavePanel(); panel.allowedContentTypes = [.pdf]; panel.nameFieldStringValue = e.label.replacingOccurrences(of: "/", with: "-") + ".pdf"; if panel.runModal() == .OK, let url = panel.url { do { try pdf(e, db: db, to: url); store.notice = "PDF esportato." } catch { store.error = error.localizedDescription } } }
    static func exportXML(_ e: Entry, store: Store) { do { let xml = try InvoiceXML.xml(e); let panel = NSSavePanel(); panel.allowedContentTypes = [.xml]; panel.nameFieldStringValue = "IT\(e.issued?.profile.contact.vat ?? "")_\(e.id.uuidString.prefix(10)).xml"; if panel.runModal() == .OK, let url = panel.url { try xml.write(to: url, atomically: true, encoding: .utf8); store.notice = "XML preparato. Verificalo con il servizio fiscale prima dell’invio: i controlli locali non replicano tutti i controlli SDI." } } catch { store.error = error.localizedDescription } }
}
