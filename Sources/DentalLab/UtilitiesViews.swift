import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @State var profile = Profile()
    @State var loaded = false
    @State var series = "FT"
    @State var seriesYear = Calendar.current.component(.year, from: Date())
    @State var nextNumber = 1
    var counterKey: String { "\(series)-\(seriesYear)" }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if store.entries.contains(where: { $0.section == "Pazienti" }) {
                Surface { DisclosureGroup("Schede paziente delle versioni precedenti") { ForEach(store.entries.filter { $0.section == "Pazienti" }) { patient in VStack(alignment: .leading) { Text(patient.name).fontWeight(.semibold); Text(patient.detail).font(.caption).foregroundColor(.secondary) }.padding(.vertical, 6) } } }
            }
            PasswordPanel(store: store)
            UpdatesPanel()
            CalendarPanel(store: store)
            Surface { VStack(alignment: .leading, spacing: 18) { SectionHeading(title: "Identità del laboratorio"); Field(title: "Ragione sociale", text: $profile.name); ContactEditor(contact: $profile.contact); HStack { Field(title: "IBAN", text: $profile.iban); Text("Regime ordinario · RF01").font(.system(size: 12)).foregroundColor(Palette.teal) } } }
            Surface { VStack(alignment: .leading, spacing: 18) { SectionHeading(title: "Fabbricante di dispositivi su misura", subtitle: "Dati da riportare nei documenti del laboratorio."); NoteField(title: "Tutti i luoghi di fabbricazione e indirizzi", text: $profile.productionSites); Field(title: "Mandatario e indirizzo, oppure Non applicabile", text: $profile.representative); HStack { Field(title: "Riferimento iscrizione elenco fabbricanti", text: $profile.registration); Field(title: "Responsabile del rispetto della normativa (PRRC)", text: $profile.prrc) }; NoteField(title: "Riferimenti alle procedure di qualità", text: $profile.qualityProcedure); NoteField(title: "Riferimenti a informativa, ruoli privacy e tempi di conservazione", text: $profile.privacyProcedure) } }
            Surface { VStack(alignment: .leading, spacing: 16) { SectionHeading(title: "Numerazione documenti", subtitle: "Imposta il prossimo numero se hai già documenti emessi fuori dall’app. I progressivi non possono essere abbassati."); HStack { Picker("Serie", selection: $series) { Text("Fatture · FT").tag("FT"); Text("Note di credito · NC").tag("NC"); Text("Preventivi · PR").tag("PR"); Text("Consegne · DDT").tag("DDT"); Text("Dichiarazioni · DSM").tag("DSM") }; TextField("Anno", value: $seriesYear, format: .number.grouping(.never)).textFieldStyle(.roundedBorder).frame(width: 90); Text("Prossimo numero").font(.system(size: 12)); TextField("Numero", value: $nextNumber, format: .number.grouping(.never)).textFieldStyle(.roundedBorder).frame(width: 100) }; Text("Ultimo progressivo riservato: \(store.db.counters[counterKey] ?? 0). Anche un ripristino su questo Mac mantiene i progressivi già riservati.").font(.caption).foregroundColor(.secondary) } }
            Surface { VStack(alignment: .leading, spacing: 14) { SectionHeading(title: "Sicurezza e recupero"); Label("Archivio e allegati cifrati con AES-GCM", systemImage: "lock.shield").font(.system(size: 12)); Text("La chiave locale è nel Portachiavi di macOS. I backup locali conservano le ultime 60 versioni dell’archivio; gli allegati restano nella cartella cifrata. Per trasferire o recuperare su Mac o Windows, esporta un backup completo protetto da password.").font(.system(size: 12)).foregroundColor(.secondary); Text("PDF, XML e allegati esportati sono copie in chiaro. Il registro attività è locale e non certificato. Imposta blocco schermo e FileVault sul Mac; definisci accessi, informativa e conservazione nel tuo processo privacy.").font(.system(size: 11)).foregroundColor(.secondary); Button("Mostra cartella archivio") { NSWorkspace.shared.open(store.folder) } } }
            HStack { Spacer(); Button("Salva impostazioni") { profile.regime = "RF01"; if store.commit("Impostazioni laboratorio aggiornate", update: { db in
                try require((1900...2200).contains(seriesYear) && nextNumber > (db.counters[counterKey] ?? 0) && nextNumber <= 999999, "Anno o progressivo non valido: il prossimo numero deve superare quelli già riservati.")
                db.profile = profile; db.counters[counterKey] = nextNumber - 1
            }) { store.notice = "Impostazioni salvate." } }.buttonStyle(LabButtonStyle(primary: true)) }
        }.onAppear { if !loaded { profile = store.db.profile; nextNumber = (store.db.counters[counterKey] ?? 0) + 1; loaded = true } }.onChange(of: series) { _ in nextNumber = (store.db.counters[counterKey] ?? 0) + 1 }.onChange(of: seriesYear) { _ in nextNumber = (store.db.counters[counterKey] ?? 0) + 1 }
    }
}
struct BackupView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @State var password = ""
    @State var confirmation = ""
    @State var restoreMode = false
    @State var file: URL?
    @State var restoring = false
    @State var issue = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "externaldrive.badge.checkmark").font(.system(size: 32)).foregroundColor(Palette.teal)
            Text("Backup e recupero").font(.title.bold())
            Picker("Operazione", selection: $restoreMode) { Text("Esporta backup").tag(false); Text("Verifica / ripristina").tag(true) }.pickerStyle(.segmented)
            Text(restoreMode ? "Il ripristino sostituisce le schede attuali con quelle del backup. La versione precedente dell’archivio viene conservata localmente." : "Il backup comprende schede, impostazioni, attività e allegati. È cifrato con una password che scegli tu e si può ripristinare su un altro Mac.").font(.system(size: 12)).foregroundColor(.secondary)
            SecureField("Password del backup (almeno 12 caratteri)", text: $password).textFieldStyle(.roundedBorder)
            if !restoreMode { SecureField("Ripeti la password", text: $confirmation).textFieldStyle(.roundedBorder); Text("Conserva la password separatamente: senza di essa il backup non è recuperabile.").font(.caption).foregroundColor(.secondary) }
            if restoreMode { Button(file?.lastPathComponent ?? "Scegli il backup…") { let p = NSOpenPanel(); p.canChooseDirectories = false; if p.runModal() == .OK { file = p.url } } }
            if restoreMode { Button("Verifica integrità senza ripristinare") { do { guard let file = file else { throw AppIssue(message: "Scegli un backup.") }; let payload = try store.verifyBackup(password: password, from: file); issue = "Backup verificato: \(payload.database.entries.count) schede, \(payload.files.count) allegati." } catch { issue = error.localizedDescription } } }
            if !issue.isEmpty { Text(issue).font(.caption).foregroundColor(.red) }
            HStack { Button("Annulla") { dismiss() }; Spacer(); Button(restoreMode ? "Ripristina…" : "Esporta…") { if restoreMode { if file == nil { issue = "Scegli un file di backup." } else { restoring = true } } else { export() } }.buttonStyle(LabButtonStyle(primary: true)) }
        }.padding(28).frame(width: 530).tint(Palette.teal)
        .alert("Sostituire l’archivio attuale?", isPresented: $restoring) { Button("Annulla", role: .cancel) {}; Button("Ripristina") { do { guard let file = file else { return }; try store.restore(password: password, from: file); dismiss() } catch { issue = "Ripristino non riuscito: \(error.localizedDescription)" } } } message: { Text("Il file sarà verificato e decifrato prima di cambiare le schede. Conserva una copia aggiornata del tuo archivio prima di procedere.") }
    }
    func export() { guard password == confirmation else { issue = "Le password non coincidono."; return }; guard password.count >= 12 else { issue = "Usa almeno 12 caratteri."; return }; let p = NSSavePanel(); p.nameFieldStringValue = "DentalLab-\(isoDay(Date())).dlbackup"; if p.runModal() == .OK, let url = p.url { do { try store.backup(password: password, to: url); dismiss() } catch { issue = error.localizedDescription } } }
}
struct MovementEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    var stockEntry: Entry
    @State var type = "Carico"
    @State var quantity: Decimal = 1
    @State var reason = ""
    @State var workID: UUID?
    var body: some View { VStack(alignment: .leading, spacing: 20) { Text("Movimento magazzino").font(.title2.bold()); Text("\(stockEntry.name) · lotto \(stockEntry.lot)").foregroundColor(.secondary); Picker("Operazione", selection: $type) { Text("Carico").tag("Carico"); Text("Scarico").tag("Scarico"); Text("Consumo lavoro").tag("Consumo") }; TextField("Quantità positiva", value: $quantity, format: .number).textFieldStyle(.roundedBorder); Field(title: "Causale", text: $reason); if type == "Consumo" { Picker("Lavoro", selection: $workID) { Text("Seleziona").tag(nil as UUID?); ForEach(store.entries.filter { $0.section == "Lavori" && !$0.isArchived }) { Text($0.name).tag(Optional($0.id)) } } }; HStack { Button("Annulla") { dismiss() }; Spacer(); Button("Registra movimento") { guard quantity > 0 else { store.error = "Inserisci una quantità positiva."; return }; guard type != "Consumo" || workID != nil else { store.error = "Seleziona il lavoro."; return }; if store.move(stockID: stockEntry.id, workID: type == "Consumo" ? workID : nil, delta: type == "Carico" ? quantity : -quantity, reason: reason) { dismiss() } }.buttonStyle(LabButtonStyle(primary: true)) } }.padding(28).frame(width: 540).tint(Palette.teal).alert("Movimento non registrato", isPresented: Binding(get: { !store.error.isEmpty }, set: { if !$0 { store.error = "" } })) { Button("OK") { store.error = "" } } message: { Text(store.error) } }
}
struct PaymentEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    var entryID: UUID
    @State var payment = Payment()
    var body: some View { VStack(alignment: .leading, spacing: 20) { Text("Registra incasso").font(.title2.bold()); DatePicker("Data", selection: $payment.date, displayedComponents: .date); TextField("Importo €", value: $payment.amount, format: .number).textFieldStyle(.roundedBorder); Picker("Metodo", selection: $payment.method) { ForEach(["Bonifico", "Contanti", "Carta", "Altro"], id: \.self) { Text($0).tag($0) } }; Field(title: "Riferimento", text: $payment.reference); HStack { Button("Annulla") { dismiss() }; Spacer(); Button("Registra") { if store.addPayment(payment, to: entryID) { dismiss() } }.buttonStyle(LabButtonStyle(primary: true)) } }.padding(28).frame(width: 500).tint(Palette.teal).alert("Incasso non registrato", isPresented: Binding(get: { !store.error.isEmpty }, set: { if !$0 { store.error = "" } })) { Button("OK") { store.error = "" } } message: { Text(store.error) } }
}
struct SDIEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    var entryID: UUID
    @State var status = "Trasmesso esternamente"
    @State var reference = ""
    var body: some View { VStack(alignment: .leading, spacing: 20) { Text("Annota ricevuta SDI").font(.title2.bold()); Text("Consulta la ricevuta del servizio fiscale. Questo esito è un’annotazione manuale e non una conferma automatica del Sistema di Interscambio.").font(.system(size: 12)).foregroundColor(.secondary); Picker("Esito", selection: $status) { ForEach(["Trasmesso esternamente", "Consegnato", "Mancata consegna", "Scartato"], id: \.self) { Text($0).tag($0) } }; Field(title: "Identificativo / riferimento ricevuta", text: $reference); HStack { Button("Annulla") { dismiss() }; Spacer(); Button("Registra esito") { if store.updateSDI(entryID, status: status, reference: reference) { dismiss() } }.buttonStyle(LabButtonStyle(primary: true)) } }.padding(28).frame(width: 520).tint(Palette.teal).alert("Esito non registrato", isPresented: Binding(get: { !store.error.isEmpty }, set: { if !$0 { store.error = "" } })) { Button("OK") { store.error = "" } } message: { Text(store.error) } }
}
