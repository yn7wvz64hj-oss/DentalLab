import SwiftUI
import AppKit

struct Field: View {
    var title: String; @Binding var text: String
    var body: some View { VStack(alignment: .leading, spacing: 6) { Text(title).font(.system(size: 11, weight: .medium)).foregroundColor(.secondary); TextField(title, text: $text).textFieldStyle(.roundedBorder) } }
}
struct NoteField: View {
    var title: String; @Binding var text: String; var height: CGFloat = 90
    var body: some View { VStack(alignment: .leading, spacing: 7) { Text(title).font(.system(size: 11, weight: .medium)).foregroundColor(.secondary); TextEditor(text: $text).font(.system(size: 12)).padding(6).frame(height: height).background(Color.white).cornerRadius(7).overlay(RoundedRectangle(cornerRadius: 7).stroke(Palette.line)) } }
}
struct Editor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @State var entry: Entry
    @State var tab = "Scheda"
    @State var attachmentCategory = "Generale"
    @State var registering = false
    @State var paying = false
    @State var sdi = false
    init(entry: Entry, initialTab: String = "Scheda") { _tab = State(initialValue: initialTab); var e = entry; if e.contact == nil { e.contact = Contact() }; if e.device == nil { e.device = Device() }; if e.quality == nil { e.quality = Quality() }; _entry = State(initialValue: e) }
    var readOnly: Bool { entry.issued != nil || entry.isArchived }
    var contact: Binding<Contact> { Binding(get: { entry.contact ?? Contact() }, set: { entry.contact = $0 }) }
    var device: Binding<Device> { Binding(get: { entry.device ?? Device() }, set: { entry.device = $0 }) }
    var quality: Binding<Quality> { Binding(get: { entry.quality ?? Quality() }, set: { entry.quality = $0 }) }
    var lines: Binding<[Line]> { Binding(get: { entry.lines ?? [] }, set: { entry.lines = $0 }) }
    var tabs: [String] { var list = ["Scheda"]; if entry.section == "Lavori" || entry.section == "Conformità" { list += ["Mappa dentale", "Dispositivo", "Fascicolo"] }; if ["Lavori", "Listino", "Preventivi", "Fatture", "Consegne"].contains(entry.section) { list.append("Righe") }; list.append("Allegati"); if entry.section == "Fatture" { list.append("Incassi") }; return list }
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) { Image(systemName: moduleIcon(entry.section)).font(.system(size: 22)).foregroundColor(Palette.teal).padding(14).background(Palette.teal.opacity(0.08)).cornerRadius(12); VStack(alignment: .leading, spacing: 6) { Text(entry.name.isEmpty ? "Nuova scheda" : entry.name).font(.system(size: 23, weight: .semibold)); Text("\(entry.section) · \(entry.issued?.number ?? "In preparazione")").font(.system(size: 11)).foregroundColor(.secondary) }; Spacer(); Badge(text: entry.issued != nil ? "Registrato · sola lettura" : entry.isArchived ? "Archiviato" : "Bozza", color: readOnly ? Palette.teal : .gray) }.padding(24).background(Color.white)
            HStack(spacing: 22) { ForEach(tabs, id: \.self) { item in Button { tab = item } label: { VStack(spacing: 10) { Text(item).font(.system(size: 12, weight: tab == item ? .semibold : .regular)).foregroundColor(tab == item ? Palette.teal : .secondary); Rectangle().fill(tab == item ? Palette.teal : .clear).frame(height: 2) } }.buttonStyle(.plain) }; Spacer() }.padding(.horizontal, 26).padding(.top, 14).background(Color.white)
            ScrollView { VStack(alignment: .leading, spacing: 18) {
                if tab == "Scheda" { general.disabled(readOnly) }
                if tab == "Mappa dentale" { DentalChart(works: Binding(get: { entry.device?.toothWorks ?? [] }, set: { entry.device?.toothWorks = $0 }), readOnly: readOnly) }
                if tab == "Dispositivo" { clinical.disabled(readOnly) }
                if tab == "Fascicolo" { dossier.disabled(readOnly) }
                if tab == "Righe" { LinesEditor(lines: lines, listino: store.entries.filter { $0.section == "Listino" && !$0.isArchived }, readOnly: readOnly); totals }
                if tab == "Allegati" { attachmentView }
                if tab == "Incassi" { paymentsView }
            }.padding(24) }.background(Palette.canvas)
            Divider()
            HStack { Button("Chiudi") { dismiss() }.keyboardShortcut(.cancelAction); Button { Documents.exportPDF(entry, db: store.db, store: store) } label: { Label("PDF", systemImage: "arrow.down.doc") }; if entry.section == "Fatture" && entry.issued != nil { Button("XML…") { Documents.exportXML(entry, store: store) } }; Spacer(); if documentSections.contains(entry.section) && !readOnly { Button("Registra documento…") { registering = true } }; if !readOnly { Button("Salva bozza") { if store.save(entry) { dismiss() } }.buttonStyle(LabButtonStyle(primary: true)).keyboardShortcut(.defaultAction) } }.padding(20).background(Color.white)
        }.buttonStyle(LabButtonStyle()).frame(width: min(990, (NSScreen.main?.visibleFrame.width ?? 1100) - 60), height: min(770, (NSScreen.main?.visibleFrame.height ?? 850) - 70)).tint(Palette.teal)
        .alert("Registrare il documento?", isPresented: $registering) { Button("Annulla", role: .cancel) {}; Button("Registra") { if store.record(entry) { dismiss() } } } message: { Text("Verrà assegnato un numero progressivo e il contenuto sarà bloccato. Verifica i dati e il trattamento fiscale. La registrazione non equivale all’invio SDI o alla firma della dichiarazione.") }
        .alert("Operazione non completata", isPresented: Binding(get: { !store.error.isEmpty }, set: { if !$0 { store.error = "" } })) { Button("OK") { store.error = "" } } message: { Text(store.error) }
        .sheet(isPresented: $paying) { PaymentEditor(entryID: entry.id).environmentObject(store) }
        .sheet(isPresented: $sdi) { SDIEditor(entryID: entry.id).environmentObject(store) }
    }
    var general: some View {
        VStack(alignment: .leading, spacing: 18) {
            Surface { VStack(alignment: .leading, spacing: 18) {
                SectionHeading(title: "Informazioni principali")
                Field(title: entry.section == "Clienti" ? "Ragione sociale / nome dello studio" : entry.section == "Pazienti" ? "Codice identificativo del paziente" : "Titolo / riferimento", text: $entry.name)
                if !["Clienti", "Magazzino", "Listino"].contains(entry.section) { customerPicker }
                if ["Lavori", "Conformità", "Pazienti"].contains(entry.section) { Field(title: "Paziente: codice, acronimo o nome", text: $entry.patient) }
                HStack(spacing: 24) { DatePicker(entry.section == "Lavori" ? "Consegna prevista" : "Data documento / scadenza", selection: $entry.date, displayedComponents: .date); if entry.section == "Lavori" { Picker("Stato", selection: $entry.status) { ForEach(workStates, id: \.self) { Text($0).tag($0) } } } }
                if !["Lavori", "Clienti", "Pazienti", "Magazzino", "Listino"].contains(entry.section) { workPicker }
            } }
            if entry.section == "Clienti" { Surface { VStack(alignment: .leading, spacing: 18) { SectionHeading(title: "Dati fiscali e contatti"); ContactEditor(contact: contact) } } }
            if entry.section == "Magazzino" { stockFields }
            if entry.section == "Consegne" { deliveryFields }
            if entry.section == "Fatture" || entry.section == "Preventivi" { fiscalFields }
            if entry.section == "Qualità" || entry.section == "Sorveglianza" { qualityFields }
            Surface { NoteField(title: entry.section == "Pazienti" ? "Riferimenti essenziali (evita dati clinici non necessari)" : "Note e condizioni", text: $entry.detail, height: 110) }
            if entry.section == "Lavori" { Surface { VStack(alignment: .leading, spacing: 12) { SectionHeading(title: "Materiali consumati", subtitle: "Registra il consumo dal Magazzino e collegalo a questo lavoro."); Text(Documents.materialText(entry, db: store.db).isEmpty ? "Nessun consumo collegato." : Documents.materialText(entry, db: store.db)).font(.system(size: 12)); Field(title: "Altri riferimenti di tracciabilità", text: $entry.lot) } } }
        }
    }
    var customerPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Cliente", selection: Binding<UUID?>(get: { entry.clientID }, set: { id in entry.clientID = id; entry.client = store.entries.first { $0.id == id }?.name ?? "" })) { Text("Seleziona un cliente").tag(nil as UUID?); ForEach(store.entries.filter { $0.section == "Clienti" && !$0.isArchived }) { Text($0.name).tag(Optional($0.id)) } }
            if entry.clientID == nil && !entry.client.isEmpty { Text("Riferimento precedente: \(entry.client)").font(.caption).foregroundColor(.secondary) }
        }
    }
    var workPicker: some View { Picker("Lavoro collegato", selection: Binding<UUID?>(get: { entry.workID }, set: { entry.workID = $0 })) { Text("Nessun collegamento").tag(nil as UUID?); ForEach(store.entries.filter { $0.section == "Lavori" && !$0.isArchived }) { Text($0.name).tag(Optional($0.id)) } } }
    var deliveryFields: some View {
        let d = Binding<Delivery>(get: { entry.delivery ?? Delivery() }, set: { entry.delivery = $0 })
        return Surface { VStack(alignment: .leading, spacing: 18) { SectionHeading(title: "Trasporto e destinazione"); Field(title: "Destinatario", text: d.recipient); Field(title: "Indirizzo di consegna", text: d.address); HStack { Field(title: "Vettore / trasporto a cura di", text: d.carrier); Field(title: "Causale trasporto", text: d.reason) }; HStack { DatePicker("Data trasporto", selection: d.transportDate, displayedComponents: [.date, .hourAndMinute]); Stepper("Colli: \(d.wrappedValue.packages)", value: d.packages, in: 1...999) } } }
    }
    var stockFields: some View {
        Surface { VStack(alignment: .leading, spacing: 18) {
            SectionHeading(title: "Lotto e disponibilità", subtitle: "Dopo la creazione usa i movimenti per variare la quantità.")
            HStack { Field(title: "Lotto", text: $entry.lot); Field(title: "Fornitore", text: Binding(get: { entry.supplier ?? "" }, set: { entry.supplier = $0 })); Field(title: "Unità di misura", text: Binding(get: { entry.unit ?? "unità" }, set: { entry.unit = $0 })) }
            HStack { VStack(alignment: .leading) { Text("Quantità iniziale").font(.caption).foregroundColor(.secondary); TextField("Quantità", value: Binding(get: { entry.available }, set: { entry.stock = $0 }), format: .number).textFieldStyle(.roundedBorder).disabled(store.entries.contains { $0.id == entry.id }) }; VStack(alignment: .leading) { Text("Scorta minima").font(.caption).foregroundColor(.secondary); TextField("Minimo", value: Binding(get: { entry.minimum ?? 0 }, set: { entry.minimum = $0 }), format: .number).textFieldStyle(.roundedBorder) } }
            Toggle("Il lotto ha una scadenza", isOn: Binding(get: { entry.expiry != nil }, set: { entry.expiry = $0 ? Date() : nil }))
            if entry.expiry != nil { DatePicker("Scadenza lotto", selection: Binding(get: { entry.expiry ?? Date() }, set: { entry.expiry = $0 }), displayedComponents: .date) }
            ForEach(store.db.movements.filter { $0.stockID == entry.id }.reversed().prefix(15)) { m in HStack { Text(day(m.date)).font(.caption); Text(m.reason); Spacer(); Text(numeric(m.delta)).font(.system(size: 12, weight: .semibold)) } }
        } }
    }
    var fiscalFields: some View {
        Surface { VStack(alignment: .leading, spacing: 18) {
            SectionHeading(title: "Condizioni economiche", subtitle: "Imposta aliquota o natura fiscale in ogni riga. Il bollo è configurato manualmente.")
            if entry.section == "Fatture" { Picker("Tipo documento", selection: Binding(get: { entry.invoiceType ?? "TD01" }, set: { entry.invoiceType = $0 })) { Text("TD01 · Fattura").tag("TD01"); Text("TD04 · Nota di credito").tag("TD04") } }
            if entry.invoiceType == "TD04" { Picker("Fattura da rettificare", selection: Binding<UUID?>(get: { entry.relatedInvoiceID }, set: { entry.relatedInvoiceID = $0 })) { Text("Seleziona fattura").tag(nil as UUID?); ForEach(store.entries.filter { $0.section == "Fatture" && $0.issued != nil && $0.invoiceType != "TD04" }) { Text($0.label + " · " + $0.client).tag(Optional($0.id)) } } }
            HStack { DatePicker("Scadenza pagamento", selection: Binding(get: { entry.paymentDue ?? entry.date }, set: { entry.paymentDue = $0 }), displayedComponents: .date); Picker("Modalità", selection: Binding(get: { entry.paymentMethod ?? "MP05" }, set: { entry.paymentMethod = $0 })) { Text("Bonifico").tag("MP05"); Text("Contanti").tag("MP01"); Text("Carta").tag("MP08") } }
            HStack { Text("Bollo addebitato (€)").font(.system(size: 12)); TextField("Bollo", value: Binding(get: { entry.stamp ?? 0 }, set: { entry.stamp = $0 }), format: .number).textFieldStyle(.roundedBorder).frame(width: 100) }
            totals
        } }
    }
    var qualityFields: some View {
        Surface { VStack(alignment: .leading, spacing: 18) {
            SectionHeading(title: entry.section == "Qualità" ? "Valutazione e azioni" : "Sorveglianza post-produzione")
            Picker("Tipo registrazione", selection: quality.kind) { ForEach(entry.section == "Qualità" ? ["Non conformità", "Controllo", "Azione correttiva", "Verifica efficacia"] : ["Reclamo", "Incidente", "Piano PMS", "Piano PMCF", "Rapporto PMS", "PSUR", "Azione di sicurezza"], id: \.self) { Text($0).tag($0) } }
            HStack { Picker("Stato", selection: $entry.status) { Text("Aperto").tag("Aperto"); Text("In verifica").tag("In verifica"); Text("Chiuso").tag("Chiuso") }; Field(title: "Responsabile", text: quality.owner); Picker("Gravità", selection: quality.severity) { ForEach(["Da valutare", "Minore", "Maggiore", "Potenziale incidente grave"], id: \.self) { Text($0).tag($0) } } }
            NoteField(title: "Analisi / causa / valutazione", text: quality.cause)
            NoteField(title: "Azioni e piano", text: quality.action)
            NoteField(title: "Risultati e verifica dell’efficacia", text: quality.result)
            if entry.section == "Sorveglianza" { Field(title: "Riferimento segnalazione alle autorità (se applicabile)", text: quality.authorityReference) }
        } }
    }
    var clinical: some View {
        VStack(spacing: 18) {
            Surface { VStack(alignment: .leading, spacing: 18) {
                SectionHeading(title: "Dispositivo su misura")
                HStack { Field(title: "Identificativo dispositivo", text: device.identifier); Picker("Tipologia", selection: device.type) { ForEach(["Protesi fissa", "Protesi mobile", "Ortodonzia", "Bite", "Riparazione", "Altro"], id: \.self) { Text($0).tag($0) } } }
                HStack { Picker("Classe di rischio", selection: device.riskClass) { ForEach(["Da valutare", "I", "IIa", "IIb", "III"], id: \.self) { Text($0).tag($0) } }; Toggle("Dispositivo impiantabile", isOn: device.implantable) }
                Text("La classe e l’eventuale impiantabilità devono essere valutate dal fabbricante.").font(.caption).foregroundColor(.secondary)
                if entry.device?.toothWorks != nil { Text("Elementi dalla mappa: " + (entry.device?.dentalElements ?? "")).font(.caption); Text("Colori dalla mappa: " + (entry.device?.dentalShades ?? "")).font(.caption).foregroundColor(.secondary) }
                else { HStack { Field(title: "Elementi dentali / arcata (testo precedente)", text: device.teeth); Field(title: "Colore / scala (testo precedente)", text: device.shade) } }
                Field(title: "Destinazione d’uso", text: device.intendedUse)
            } }
            Surface { VStack(alignment: .leading, spacing: 18) {
                SectionHeading(title: "Prescrizione")
                HStack { Field(title: "Prescrittore autorizzato", text: device.prescriber); Field(title: "Istituzione sanitaria (se applicabile)", text: device.institution) }
                DatePicker("Data prescrizione", selection: device.prescriptionDate, displayedComponents: .date)
                NoteField(title: "Caratteristiche specifiche richieste", text: device.prescription, height: 130)
                Text("Aggiungi la prescrizione firmata negli Allegati, categoria Prescrizione.").font(.caption).foregroundColor(.secondary)
            } }
        }
    }
    var dossier: some View {
        VStack(spacing: 18) {
            if entry.section == "Conformità" { Surface { VStack(alignment: .leading, spacing: 12) { SectionHeading(title: "Controllo di completezza", subtitle: "Verifica dei campi richiesti dal flusso; non è una certificazione."); let missing = Validation.mdr(entry, profile: store.db.profile); if missing.isEmpty { Label("I campi previsti sono completi", systemImage: "checkmark.circle").foregroundColor(Palette.teal) }; ForEach(missing, id: \.self) { Label($0, systemImage: "circle").font(.system(size: 11)).foregroundColor(.secondary) } } } }
            Surface { VStack(alignment: .leading, spacing: 18) { SectionHeading(title: "Documentazione tecnica"); NoteField(title: "Progettazione e riferimenti ai file", text: device.design); NoteField(title: "Fabbricazione e processo", text: device.manufacturing); NoteField(title: "Prestazioni previste e valutazione", text: device.performance); NoteField(title: "Gestione dei rischi e riferimenti alla valutazione clinica", text: device.risks) } }
            Surface { VStack(alignment: .leading, spacing: 18) {
                SectionHeading(title: "Sicurezza, prestazione e rilascio")
                NoteField(title: "Requisiti applicabili dell’Allegato I e riferimenti alle verifiche", text: device.requirements)
                NoteField(title: "Requisiti non interamente rispettati e motivazione (se applicabile)", text: device.exceptions)
                Field(title: "Sostanze medicinali / tessuti e cellule: assenti o descrizione", text: device.substances)
                NoteField(title: "Controlli finali ed esiti", text: device.checks)
                NoteField(title: "Istruzioni, manutenzione e rischi residui", text: device.instructions)
                HStack { Field(title: "Responsabile della verifica", text: device.reviewer); DatePicker("Immissione sul mercato", selection: device.releaseDate, displayedComponents: .date) }
                Toggle("Il fabbricante conferma la verifica della conformità ai requisiti applicabili", isOn: device.conformityConfirmed)
            } }
        }
    }
    var totals: some View { HStack { Spacer(); VStack(alignment: .trailing, spacing: 8) { Text("Imponibile \(money(entry.net))").font(.system(size: 12)).foregroundColor(.secondary); Text("IVA \(money(entry.tax))").font(.system(size: 12)).foregroundColor(.secondary); Text("Totale \(money(entry.total))").font(.system(size: 22, weight: .semibold)).foregroundColor(Palette.ink) } }.padding(12) }
    var attachmentView: some View {
        Surface { VStack(alignment: .leading, spacing: 18) {
            HStack { SectionHeading(title: "Archivio allegati", subtitle: "I file vengono copiati e cifrati nell’archivio."); Spacer(); if !readOnly { Picker("Categoria", selection: $attachmentCategory) { ForEach(["Generale", "Prescrizione", "Progettazione", "Materiali", "Rischi", "Valutazione clinica", "Controlli", "Istruzioni", "Ricevuta SDI"], id: \.self) { Text($0).tag($0) } }.frame(width: 190); Button("Aggiungi…", action: attach) } }
            ForEach(entry.files ?? []) { f in HStack { Image(systemName: "doc").foregroundColor(Palette.teal); VStack(alignment: .leading, spacing: 4) { Text(f.name).font(.system(size: 12, weight: .medium)); Text(f.category).font(.caption).foregroundColor(.secondary) }; Spacer(); Button("Esporta…") { store.exportAttachment(f) }; if !readOnly { Button { entry.files?.removeAll { $0.id == f.id } } label: { Image(systemName: "minus.circle") }.buttonStyle(LabButtonStyle(subtle: true)) } }; Divider() }
            if (entry.files ?? []).isEmpty { Text("Nessun allegato. Puoi aggiungere foto, PDF, STL e altri file fino a 100 MB ciascuno.").font(.system(size: 12)).foregroundColor(.secondary).padding(.vertical, 30) }
        } }
    }
    var paymentsView: some View {
        let current = store.entries.first { $0.id == entry.id } ?? entry
        return VStack(spacing: 18) {
            HStack { Metric(title: "Totale", value: money(current.total), note: "Importo del documento", icon: "doc.text"); Metric(title: "Incassato", value: money(current.received), note: "Pagamenti registrati", icon: "checkmark.circle"); Metric(title: "Saldo", value: money(store.outstanding(current)), note: "Importo residuo", icon: "eurosign.circle") }
            Surface { VStack(alignment: .leading, spacing: 15) {
                HStack { SectionHeading(title: "Pagamenti"); Spacer(); Button("Registra incasso…") { paying = true }.disabled(!store.entries.contains { $0.id == entry.id } || store.outstanding(current) == 0 || current.invoiceType == "TD04") }
                ForEach(current.payments ?? []) { p in HStack { Text(day(p.date)); Text(p.method).foregroundColor(.secondary); Text(p.reference).font(.caption); Spacer(); Text(money(p.amount)).fontWeight(.semibold) } }
                if current.payments == nil && current.paid { Text("Saldo importato dalla versione precedente.").font(.caption).foregroundColor(.secondary) }
            } }
            Surface { VStack(alignment: .leading, spacing: 14) { HStack { SectionHeading(title: "Sistema di Interscambio", subtitle: "Esiti annotati manualmente, con riferimento alla ricevuta esterna."); Spacer(); Button("Annota esito…") { sdi = true }.disabled(current.issued == nil) }; Badge(text: current.sdiStatus ?? "Non trasmesso dall’app", color: .gray); Text(current.sdiReference ?? "").font(.caption) } }
        }
    }
    func attach() { let panel = NSOpenPanel(); panel.allowsMultipleSelection = true; panel.canChooseDirectories = false; if panel.runModal() == .OK { do { var files = entry.files ?? []; for url in panel.urls { files.append(try store.attach(url, category: attachmentCategory)) }; entry.files = files } catch { store.error = error.localizedDescription } } }
}
struct ContactEditor: View {
    @Binding var contact: Contact
    var body: some View { VStack(spacing: 16) { HStack { Field(title: "Partita IVA", text: $contact.vat); Field(title: "Codice fiscale", text: $contact.taxCode) }; Field(title: "Indirizzo", text: $contact.address); HStack { Field(title: "CAP", text: $contact.zip); Field(title: "Comune", text: $contact.city); Field(title: "Provincia", text: $contact.province) }; HStack { Field(title: "Email", text: $contact.email); Field(title: "Telefono", text: $contact.phone) }; HStack { Field(title: "Codice destinatario SDI", text: $contact.recipient); Field(title: "PEC", text: $contact.pec) } } }
}
struct LinesEditor: View {
    @Binding var lines: [Line]; var listino: [Entry]; var readOnly: Bool
    var body: some View {
        Surface { VStack(alignment: .leading, spacing: 18) {
            HStack { SectionHeading(title: "Lavorazioni e importi", subtitle: "Calcolo con decimali e arrotondamento al centesimo."); Spacer(); if !readOnly { Menu("Dal listino") { ForEach(listino) { item in Button(item.name) { if !item.items.isEmpty { for l in item.items { var new = l; new.id = UUID(); lines.append(new) } } else { var l = Line(); l.title = item.name; l.unitPrice = Decimal(item.price); lines.append(l) } } } }; Button("Aggiungi riga") { lines.append(Line()) } } }
            ForEach($lines) { $line in VStack(alignment: .leading, spacing: 12) {
                HStack { Field(title: "Descrizione", text: $line.title); if !readOnly { Button { lines.removeAll { $0.id == line.id } } label: { Image(systemName: "minus.circle") }.buttonStyle(LabButtonStyle(subtle: true)) } }
                HStack(spacing: 15) { number("Quantità", $line.quantity); number("Prezzo unitario €", $line.unitPrice); number("Sconto %", $line.discount); number("IVA %", $line.vat); VStack(alignment: .trailing, spacing: 7) { Text("Imponibile").font(.caption).foregroundColor(.secondary); Text(money(line.net)).font(.system(size: 14, weight: .semibold)) }.frame(width: 120) }
                if line.vat == 0 { HStack { Picker("Natura", selection: $line.nature) { Text("Da definire").tag(""); ForEach(InvoiceXML.natures, id: \.self) { Text($0).tag($0) } }.frame(width: 180); Field(title: "Riferimento fiscale / motivo esenzione", text: $line.taxReference) } }
                Divider()
            }.disabled(readOnly) }
            if lines.isEmpty { Text("Aggiungi le lavorazioni. Nessun trattamento IVA viene scelto automaticamente.").font(.system(size: 12)).foregroundColor(.secondary).padding(.vertical, 24) }
        } }
    }
    func number(_ title: String, _ value: Binding<Decimal>) -> some View { VStack(alignment: .leading, spacing: 6) { Text(title).font(.system(size: 10)).foregroundColor(.secondary); TextField(title, value: value, format: .number).textFieldStyle(.roundedBorder) } }
}
