import SwiftUI
import AppKit

struct Palette {
    static let teal = Color(red: 0.02, green: 0.43, blue: 0.56)
    static let cyan = Color(red: 0.30, green: 0.88, blue: 0.96)
    static let violet = Color(red: 0.39, green: 0.43, blue: 0.77)
    static let navy = Color(red: 0.045, green: 0.075, blue: 0.14)
    static let canvas = Color(red: 0.90, green: 0.945, blue: 0.985)
    static let ink = Color(red: 0.10, green: 0.15, blue: 0.23)
    static let line = Color(red: 0.84, green: 0.89, blue: 0.94)
    static let sidebar = LinearGradient(colors: [navy, Color(red: 0.08, green: 0.16, blue: 0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let action = LinearGradient(colors: [Color(red: 0.22, green: 0.26, blue: 0.58), teal], startPoint: .topLeading, endPoint: .bottomTrailing)
}
struct WorkspaceBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.white, Palette.canvas], startPoint: .topLeading, endPoint: .bottomTrailing)
            GeometryReader { geometry in
                Path { lines in
                    for x in stride(from: CGFloat(0), through: geometry.size.width, by: 64) { lines.move(to: CGPoint(x: x, y: 0)); lines.addLine(to: CGPoint(x: x, y: geometry.size.height)) }
                    for y in stride(from: CGFloat(0), through: geometry.size.height, by: 64) { lines.move(to: CGPoint(x: 0, y: y)); lines.addLine(to: CGPoint(x: geometry.size.width, y: y)) }
                }.stroke(Palette.teal.opacity(0.09), lineWidth: 0.5)
            }.accessibilityHidden(true)
        }.allowsHitTesting(false)
    }
}
struct LabButtonStyle: ButtonStyle {
    var primary = false
    var subtle = false
    @Environment(\.isEnabled) var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .semibold)).labelStyle(.titleAndIcon)
            .foregroundColor(primary ? .white : Palette.teal)
            .padding(.horizontal, subtle ? 0 : 14).padding(.vertical, subtle ? 3 : 9)
            .background { if primary { Palette.action } else { (subtle ? Color.clear : Color.white) } }
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(primary ? Palette.cyan.opacity(0.25) : subtle ? .clear : Palette.line))
            .shadow(color: primary ? Palette.teal.opacity(0.28) : .clear, radius: 9, y: 4)
            .opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.4)
    }
}
struct Surface<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View { content.padding(22).padding(.top, 8).background(LinearGradient(colors: [Color.white.opacity(0.98), Color.white.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)).cornerRadius(20).overlay(RoundedRectangle(cornerRadius: 20).stroke(LinearGradient(colors: [Palette.cyan.opacity(0.55), Palette.line], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)).overlay(alignment: .topLeading) { Capsule().fill(LinearGradient(colors: [Palette.cyan, Palette.violet], startPoint: .leading, endPoint: .trailing)).frame(width: 76, height: 3).padding(.leading, 22).padding(.top, 12) }.shadow(color: Palette.teal.opacity(0.10), radius: 20, y: 7) }
}
struct Badge: View {
    var text: String
    var color: Color = Palette.teal
    var body: some View { Text(text).font(.system(size: 11, weight: .semibold)).padding(.horizontal, 11).padding(.vertical, 6).foregroundColor(color).background(color.opacity(0.08)).clipShape(Capsule()).overlay(Capsule().stroke(color.opacity(0.16), lineWidth: 0.7)) }
}
struct SectionHeading: View {
    var title: String; var subtitle: String = ""
    var body: some View { VStack(alignment: .leading, spacing: 4) { Text(title).font(.system(size: 17, weight: .semibold)).foregroundColor(Palette.ink); if !subtitle.isEmpty { Text(subtitle).font(.system(size: 12)).foregroundColor(.secondary) } } }
}
struct Metric: View {
    var title: String; var value: String; var note: String; var icon: String; var color = Palette.teal
    var body: some View { Surface { VStack(alignment: .leading, spacing: 12) { HStack { Text(title).font(.system(size: 12, weight: .medium)).foregroundColor(.secondary); Spacer(); Image(systemName: icon).foregroundColor(color).padding(8).background(color.opacity(0.09)).cornerRadius(9) }; Text(value).font(.system(size: 29, weight: .semibold, design: .rounded)).foregroundColor(Palette.ink); Text(note).font(.system(size: 11)).foregroundColor(.secondary) }.frame(maxWidth: .infinity, alignment: .leading) } }
}
func moduleIcon(_ s: String) -> String { switch s { case "Panoramica": return "square.grid.2x2"; case "Lavori": return "shippingbox"; case "Scadenze": return "calendar"; case "Clienti": return "building.2"; case "Pazienti": return "person.crop.circle"; case "Listino": return "tag"; case "Preventivi": return "doc.text"; case "Consegne": return "shippingbox.fill"; case "Fatture": return "eurosign.circle"; case "Magazzino": return "square.stack.3d.up"; case "Conformità": return "checkmark.shield"; case "Qualità": return "checklist"; case "Sorveglianza": return "eye"; case "Attività": return "clock.arrow.circlepath"; default: return "slider.horizontal.3" } }
func moduleSubtitle(_ s: String) -> String { switch s { case "Panoramica": return "Una visione chiara del tuo laboratorio."; case "Lavori": return "Dalla prescrizione alla consegna, un fascicolo per ogni lavoro."; case "Scadenze": return "Le consegne in ordine di priorità."; case "Clienti": return "Studi, prescrittori e dati di fatturazione."; case "Pazienti": return "Identificativi e riferimenti essenziali."; case "Listino": return "Lavorazioni e prezzi del tuo laboratorio."; case "Preventivi": return "Proposte con righe, sconti e imposte."; case "Consegne": return "Documenti collegati ai lavori."; case "Fatture": return "Documenti, incassi e preparazione XML."; case "Magazzino": return "Materiali, lotti, scadenze e movimenti."; case "Conformità": return "Dichiarazioni e fascicoli dei dispositivi su misura."; case "Qualità": return "Non conformità, controlli e azioni correttive."; case "Sorveglianza": return "Reclami, esperienza post-produzione e vigilanza."; case "Attività": return "Cronologia delle operazioni salvate nell’archivio."; default: return "Laboratorio, sicurezza e copie di recupero." } }

struct ContentView: View {
    @EnvironmentObject var store: Store
    @State var section = "Panoramica"
    @State var search = ""
    @State var filter = "Attivi"
    @State var editing: Entry?
    @State var archiving: Entry?
    @State var backup = false
    @State var movement: Entry?
    @State var workYear = 0
    @State var workStage = "Tutte le fasi"
    @State var dueFilter = "Tutte le date"
    var workYears: [Int] { WorkYear.available(store.entries) }
    var active: [Entry] { store.entries.filter { !$0.isArchived } }
    var openWorks: [Entry] { active.filter { $0.section == "Lavori" && $0.status != "Consegnato" } }
    func matchesProduction(_ e: Entry) -> Bool {
        guard section == "Lavori" || section == "Scadenze" else { return true }
        let today = Calendar.current.startOfDay(for: Date())
        let due = Calendar.current.startOfDay(for: e.date)
        return (workStage == "Tutte le fasi" || e.status == workStage) && (dueFilter == "Tutte le date" || (e.status != "Consegnato" && (dueFilter == "Oggi" ? due == today : due < today)))
    }
    var rows: [Entry] {
        store.entries.filter { e in
            let correct = section == "Scadenze" ? (e.section == "Lavori" && e.status != "Consegnato") || (["Qualità", "Sorveglianza"].contains(e.section) && e.status != "Chiuso") : e.section == section
            return correct && matchesProduction(e) && (section != "Lavori" || workYear == 0 || WorkYear.of(e) == workYear) && (filter == "Archiviati" ? e.isArchived : !e.isArchived) && (filter != "Bozze" || e.issued == nil) && (filter != "Registrati" || e.issued != nil) && (search.isEmpty || "\(e.name) \(e.client) \(e.patient) \(e.lot) \(e.issued?.number ?? "") \(e.device?.identifier ?? "")".localizedCaseInsensitiveContains(search))
        }.sorted { section == "Scadenze" ? $0.date < $1.date : ($0.updated ?? $0.date) > ($1.updated ?? $1.date) }
    }
    var body: some View {
        ZStack {
            if store.ready && !store.locked { HStack(spacing: 0) { sidebar; main } }
            if store.locked || !store.ready {
                WorkspaceBackdrop().ignoresSafeArea()
                if store.ready { AccessScreen(store: store) }
                else { VStack(spacing: 20) { Text("Archivio non disponibile").font(.title.bold()); Text(store.error).multilineTextAlignment(.center).frame(maxWidth: 520); Button("Ripristina backup…") { backup = true } } }

            }
        }
        .sheet(item: $editing) { e in Editor(entry: e).environmentObject(store) }
        .sheet(item: $movement) { e in MovementEditor(stockEntry: e).environmentObject(store) }
        .sheet(isPresented: $backup) { BackupView().environmentObject(store) }
        .alert("Archiviare questa scheda?", isPresented: Binding(get: { archiving != nil }, set: { if !$0 { archiving = nil } })) { Button("Annulla", role: .cancel) { archiving = nil }; Button("Archivia") { if let e = archiving { store.archive(e) }; archiving = nil } } message: { Text("La scheda rimane nell’archivio e nel backup. I documenti registrati mantengono numero e contenuto.") }
        .alert("Operazione non completata", isPresented: Binding(get: { !store.error.isEmpty && store.ready }, set: { if !$0 { store.error = "" } })) { Button("OK") { store.error = "" } } message: { Text(store.error) }
        .onChange(of: store.locked) { locked in if locked { editing = nil; movement = nil; archiving = nil; backup = false; search = "" } }
        .onChange(of: section) { _ in search = ""; filter = "Attivi" }
    }
    var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) { BrandMark().frame(width: 36, height: 44).shadow(color: Palette.cyan.opacity(0.3), radius: 12); VStack(alignment: .leading, spacing: 5) { Text("DentalLab").font(.system(size: 23, weight: .semibold, design: .rounded)); Text("LABORATORIO DIGITALE").font(.system(size: 8, weight: .semibold)).tracking(1.7).foregroundColor(Palette.cyan.opacity(0.85)) } }.padding(.horizontal, 22).padding(.top, 38).padding(.bottom, 28)
            ScrollView { VStack(alignment: .leading, spacing: 4) {
                navGroup("OPERATIVITÀ", ["Panoramica", "Lavori", "Scadenze"])
                navGroup("ANAGRAFICHE", ["Clienti", "Pazienti", "Listino"])
                navGroup("AMMINISTRAZIONE", ["Preventivi", "Consegne", "Fatture", "Magazzino"])
                navGroup("DOCUMENTAZIONE", ["Conformità", "Qualità", "Sorveglianza"])
                navGroup("ARCHIVIO", ["Attività", "Impostazioni"])
            }.padding(.horizontal, 12) }
            Divider().overlay(Color.white.opacity(0.1)).padding(.horizontal, 20)
            HStack(spacing: 10) { Circle().fill(Palette.teal).frame(width: 32, height: 32).overlay(Text("DL").font(.system(size: 11, weight: .bold))); VStack(alignment: .leading) { Text(store.db.profile.name.isEmpty ? "Il tuo laboratorio" : store.db.profile.name).font(.system(size: 11, weight: .medium)).lineLimit(1); Text("Archivio locale cifrato").font(.system(size: 9)).opacity(0.5) }; Spacer(); Button { store.lock() } label: { Image(systemName: "lock").foregroundColor(.white.opacity(0.6)) }.buttonStyle(.plain).help("Blocca archivio") }.padding(20)
        }.foregroundColor(.white).frame(width: 248).background(Palette.sidebar).overlay(alignment: .trailing) { Rectangle().fill(Palette.cyan.opacity(0.18)).frame(width: 1) }
    }
    func navGroup(_ title: String, _ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 8, weight: .semibold)).tracking(1.4).foregroundColor(.white.opacity(0.55)).padding(.leading, 14).padding(.top, 17).padding(.bottom, 5)
            ForEach(items, id: \.self) { item in Button { section = item; workStage = "Tutte le fasi"; dueFilter = "Tutte le date"; workYear = 0 } label: {
                HStack(spacing: 11) {
                    Image(systemName: moduleIcon(item)).font(.system(size: 14)).frame(width: 18).foregroundColor(section == item ? Palette.cyan : .white.opacity(0.72))
                    Text(item == "Panoramica" ? "Oggi · panoramica" : item == "Clienti" ? "Studi e contatti" : item).font(.system(size: 12, weight: section == item ? .semibold : .regular)); Spacer()
                    if item == "Lavori" && !openWorks.isEmpty { Text("\(openWorks.count)").font(.system(size: 10, weight: .semibold)).padding(.horizontal, 7).padding(.vertical, 3).background(Palette.cyan.opacity(0.12)).cornerRadius(6) }
                }.foregroundColor(section == item ? .white : .white.opacity(0.76)).padding(.horizontal, 14).padding(.vertical, 11)
                    .background(section == item ? Palette.cyan.opacity(0.10) : .clear).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(section == item ? Palette.cyan.opacity(0.25) : .clear))
                    .overlay(alignment: .leading) { if section == item { Capsule().fill(Palette.cyan).frame(width: 3, height: 18).padding(.leading, 3) } }
            }.buttonStyle(.plain) }
        }
    }
    var main: some View {
        VStack(spacing: 0) {
            HStack { Text("LABORATORIO").font(.system(size: 9, weight: .semibold)).tracking(1.4).foregroundColor(.secondary); Text("/").foregroundColor(Palette.line); Text(section).font(.system(size: 12, weight: .medium)); Spacer(); Badge(text: "Archivio locale", color: Palette.teal); Button { backup = true } label: { Label("Backup USB", systemImage: "externaldrive") }.buttonStyle(LabButtonStyle()) }.padding(.horizontal, 30).frame(height: 68).background(Color.white.opacity(0.95)).overlay(alignment: .bottom) { Rectangle().fill(Palette.line.opacity(0.6)).frame(height: 1) }
            ScrollView { VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) { VStack(alignment: .leading, spacing: 7) { Text(section == "Panoramica" ? "Il laboratorio, oggi." : section).font(.system(size: 29, weight: .semibold, design: .rounded)).foregroundColor(.white); Text(moduleSubtitle(section)).font(.system(size: 12)).foregroundColor(.white.opacity(0.75)) }; Spacer(); if !["Panoramica", "Attività", "Impostazioni"].contains(section) { Button { editing = store.create(section == "Scadenze" ? "Lavori" : section) } label: { Label(section == "Lavori" ? "Nuovo lavoro" : "Nuova scheda", systemImage: "plus").padding(.vertical, 5) }.buttonStyle(LabButtonStyle(primary: true)) } }.padding(20).background(Palette.sidebar).cornerRadius(18).overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.cyan.opacity(0.4), lineWidth: 1))
                if !store.notice.isEmpty { HStack { Image(systemName: "info.circle"); Text(store.notice).font(.system(size: 11)); Spacer(); Button { store.notice = "" } label: { Image(systemName: "xmark") }.buttonStyle(.plain) }.foregroundColor(Palette.teal).padding(12).background(Palette.teal.opacity(0.06)).cornerRadius(10) }
                if section == "Panoramica" { dashboard }
                else if section == "Impostazioni" { SettingsView().environmentObject(store) }
                else if section == "Attività" { auditView }
                else { records }
            }.padding(30).frame(maxWidth: .infinity, alignment: .leading) }
        }.background { WorkspaceBackdrop() }
    }
    var dashboard: some View {
        VStack(alignment: .leading, spacing: 24) {
            Surface { HStack(spacing: 14) {
                SectionHeading(title: "Accesso rapido", subtitle: "Dalla prescrizione alla consegna")
                Spacer()
                Button { editing = store.create("Lavori") } label: { Label("Nuovo lavoro", systemImage: "plus") }.buttonStyle(LabButtonStyle(primary: true))
                Button("Consegne oggi") { section = "Scadenze"; workStage = "Tutte le fasi"; dueFilter = "Oggi" }
                Button("In ritardo") { section = "Scadenze"; workStage = "Tutte le fasi"; dueFilter = "In ritardo" }
                Button("Studi e contatti") { section = "Clienti" }
            } }
            HStack(spacing: 14) {
                Metric(title: "Lavori aperti", value: "\(openWorks.count)", note: "In tutte le fasi di produzione", icon: "shippingbox")
                Metric(title: "Consegne scadute", value: "\(openWorks.filter { Calendar.current.startOfDay(for: $0.date) < Calendar.current.startOfDay(for: Date()) }.count)", note: "Da ripianificare o consegnare", icon: "calendar.badge.exclamationmark", color: .orange)
                Metric(title: "Da incassare", value: money(active.filter { $0.section == "Fatture" && $0.invoiceType != "TD04" }.reduce(0) { $0 + store.outstanding($1) }), note: "Saldo dei documenti registrati e bozze", icon: "eurosign.circle")
            }
            HStack(alignment: .top, spacing: 18) {
                Surface { VStack(alignment: .leading, spacing: 20) {
                    HStack { SectionHeading(title: "Prossime consegne", subtitle: "La tua agenda di produzione"); Spacer(); Button("Tutte") { section = "Scadenze" }.buttonStyle(LabButtonStyle(subtle: true)) }
                    if openWorks.isEmpty { empty("La tua agenda è libera", "Crea il primo lavoro e imposta la data di consegna.", "calendar") }
                    else { ForEach(openWorks.sorted { $0.date < $1.date }.prefix(6)) { e in HStack { RoundedRectangle(cornerRadius: 8).fill(Palette.teal.opacity(0.08)).frame(width: 38, height: 38).overlay(Image(systemName: "shippingbox").foregroundColor(Palette.teal)); VStack(alignment: .leading, spacing: 4) { Text(e.name).font(.system(size: 12, weight: .semibold)); Text(e.client.isEmpty ? "Cliente da collegare" : e.client).font(.system(size: 10)).foregroundColor(.secondary) }; Spacer(); Text(day(e.date)).font(.system(size: 10)).foregroundColor(.secondary); Badge(text: e.status); Button { editing = e } label: { Image(systemName: "arrow.up.right") }.buttonStyle(.plain) }; Divider() } }
                }.frame(maxWidth: .infinity, alignment: .leading) }
                Surface { VStack(alignment: .leading, spacing: 18) {
                    SectionHeading(title: "Produzione", subtitle: "Ogni fase, sotto controllo")
                    ForEach(workStates.dropLast(), id: \.self) { status in Button { section = "Lavori"; workStage = status; dueFilter = "Tutte le date" } label: { HStack { Text(status).font(.system(size: 12)); Spacer(); Text("\(openWorks.filter { $0.status == status }.count)").font(.system(size: 13, weight: .semibold)); Image(systemName: "chevron.right").font(.system(size: 9)) }.contentShape(Rectangle()) }.buttonStyle(.plain); GeometryReader { g in Capsule().fill(Palette.canvas).overlay(alignment: .leading) { Capsule().fill(Palette.teal.opacity(0.7)).frame(width: g.size.width * CGFloat(openWorks.filter { $0.status == status }.count) / CGFloat(max(1, openWorks.count))) } }.frame(height: 5) }
                    Divider(); Button { editing = store.create("Lavori") } label: { Label("Aggiungi un lavoro", systemImage: "plus.circle") }.buttonStyle(LabButtonStyle(subtle: true))
                }.frame(width: 220, alignment: .leading) }
            }
            HStack(spacing: 18) {
                Surface { VStack(alignment: .leading, spacing: 12) { SectionHeading(title: "Documentazione", subtitle: "Fascicoli e dichiarazioni per dispositivi su misura"); Text("\(active.filter { $0.section == "Conformità" && $0.issued == nil }.count) bozze da completare").font(.system(size: 14, weight: .medium)); Button("Apri conformità") { section = "Conformità" }.buttonStyle(LabButtonStyle(subtle: true)) }.frame(maxWidth: .infinity, alignment: .leading) }
                Surface { VStack(alignment: .leading, spacing: 12) { SectionHeading(title: "Scorte da controllare", subtitle: "Materiali al minimo o lotti scaduti"); Text("\(active.filter { $0.section == "Magazzino" && ($0.available <= ($0.minimum ?? 0) || ($0.expiry ?? .distantFuture) < Date()) }.count) lotti richiedono attenzione").font(.system(size: 14, weight: .medium)); Button("Apri magazzino") { section = "Magazzino" }.buttonStyle(LabButtonStyle(subtle: true)) }.frame(maxWidth: .infinity, alignment: .leading) }
            }
        }
    }
    var records: some View {
        VStack(alignment: .leading, spacing: 18) {
            if section == "Lavori" || section == "Scadenze" { Surface { HStack {
                Picker("Fase", selection: $workStage) { Text("Tutte le fasi").tag("Tutte le fasi"); ForEach(workStates, id: \.self) { Text($0).tag($0) } }.frame(maxWidth: 250)
                Picker("Consegna", selection: $dueFilter) { ForEach(["Tutte le date", "Oggi", "In ritardo"], id: \.self) { Text($0).tag($0) } }.frame(maxWidth: 230)
                Spacer()
                Button("Azzera filtri") { workStage = "Tutte le fasi"; dueFilter = "Tutte le date"; workYear = 0; search = ""; filter = "Attivi" }
            } } }
            if section == "Fatture" || section == "Conformità" || section == "Sorveglianza" { Surface { HStack(alignment: .top, spacing: 12) { Image(systemName: "info.circle").foregroundColor(Palette.teal); Text(section == "Fatture" ? "Prepara XML e copia di cortesia. Invio SDI, verifica delle ricevute e conservazione fiscale si effettuano con il servizio fiscale esterno." : section == "Conformità" ? "Modello strutturato per l’Allegato XIII. La completezza dei campi non certifica la conformità del dispositivo; verifica e firma spettano al fabbricante." : "Registra l’esperienza post-produzione e le azioni. Gli incidenti e le segnalazioni alle autorità richiedono la procedura esterna di vigilanza.").font(.system(size: 11)).foregroundColor(.secondary) } } }
            HStack { HStack { Image(systemName: "magnifyingglass").foregroundColor(.secondary); TextField("Cerca in \(section.lowercased())…", text: $search).textFieldStyle(.plain) }.padding(11).background(Color.white).cornerRadius(9).overlay(RoundedRectangle(cornerRadius: 9).stroke(Palette.line)).frame(maxWidth: 360); Spacer(); if section == "Lavori" { Picker("Anno di consegna", selection: $workYear) { Text("Tutti gli anni").tag(0); ForEach(workYears, id: \.self) { year in Text(String(year)).tag(year) } }.frame(width: 220) }; Picker("Visualizza", selection: $filter) { Text("Attivi").tag("Attivi"); if documentSections.contains(section) { Text("Bozze").tag("Bozze"); Text("Registrati").tag("Registrati") }; Text("Archiviati").tag("Archiviati") }.labelsHidden().frame(width: 160); Text("\(rows.count) schede").font(.system(size: 11)).foregroundColor(.secondary) }
            Surface { VStack(alignment: .leading, spacing: 0) {
                HStack { Text("RIFERIMENTO").frame(maxWidth: .infinity, alignment: .leading); Text(section == "Magazzino" ? "DISPONIBILITÀ" : "STATO").frame(width: 140, alignment: .leading); Text("DATA").frame(width: 105, alignment: .leading); Text("AZIONI").frame(width: 112, alignment: .trailing) }.font(.system(size: 9, weight: .semibold)).tracking(0.8).foregroundColor(.secondary).padding(.bottom, 14)
                Divider()
                if rows.isEmpty { empty("Il tuo archivio inizia qui", "Aggiungi una scheda oppure modifica i filtri di ricerca.", moduleIcon(section)).padding(.vertical, 35) }
                if section == "Lavori" {
                    ForEach(Array(Set(rows.map { WorkYear.of($0) })).sorted(by: >), id: \.self) { year in
                        HStack { Text(String(year)).font(.system(size: 18, weight: .semibold)); Spacer(); Text("\(rows.filter { WorkYear.of($0) == year }.count) lavori").font(.caption).foregroundColor(.secondary) }.padding(.vertical, 16)
                        ForEach(rows.filter { WorkYear.of($0) == year }) { e in recordRow(e); Divider() }
                    }
                } else { ForEach(rows) { e in recordRow(e); Divider() } }
            } }
        }
    }
    func recordRow(_ e: Entry) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 9).fill(Palette.canvas).frame(width: 40, height: 40).overlay(Image(systemName: moduleIcon(e.section)).foregroundColor(Palette.teal))
            VStack(alignment: .leading, spacing: 5) { Text(e.label).font(.system(size: 12, weight: .semibold)).foregroundColor(Palette.ink); Text([e.issued != nil ? e.name : "", e.client, e.patient, e.section == "Magazzino" ? "Lotto " + e.lot : e.device?.identifier ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1) }.frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 5) {
                if e.section == "Magazzino" { Text("\(numeric(e.available)) \(e.unit ?? "unità")").font(.system(size: 12, weight: .medium)); if e.available <= (e.minimum ?? 0) { Badge(text: "Scorta minima", color: .orange) } }
                else if documentSections.contains(e.section) { Badge(text: e.issued == nil ? "Bozza" : "Registrato", color: e.issued == nil ? .gray : Palette.teal); if e.section == "Fatture" || e.section == "Preventivi" { Text(money(e.total)).font(.system(size: 11, weight: .medium)) } }
                else { Badge(text: e.section == "Lavori" || e.section == "Qualità" || e.section == "Sorveglianza" ? e.status : "Scheda") }
            }.frame(width: 140, alignment: .leading)
            Text(day(e.date)).font(.system(size: 10)).foregroundColor(.secondary).frame(width: 105, alignment: .leading)
            HStack { Button("Apri") { editing = e }.buttonStyle(LabButtonStyle()); Menu { Button("Esporta PDF…") { Documents.exportPDF(e, db: store.db, store: store) }; if e.section == "Magazzino" { Button("Movimento…") { movement = e } }; if e.section == "Lavori" { Button("Crea preventivo") { editing = store.create("Preventivi", from: e) }; Button("Crea documento di consegna") { editing = store.create("Consegne", from: e) }; Button("Crea dichiarazione") { editing = store.create("Conformità", from: e) }; Button("Crea fattura") { var new = store.create("Fatture", from: e); new.patient = ""; new.files = []; new.detail = "Riferimento lavoro: \(e.name)"; editing = new } }; if e.section == "Fatture" && e.issued != nil { Button("Esporta XML…") { Documents.exportXML(e, store: store) }; Button("Crea nota di credito") { var new = store.create("Fatture", from: e); new.invoiceType = "TD04"; new.relatedInvoiceID = e.id; new.detail = "Rettifica fattura \(e.label) del \(day(e.date))"; new.patient = ""; new.files = []; editing = new } }; if !e.isArchived { Button("Archivia…") { archiving = e } } } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).frame(width: 22) }.frame(width: 112, alignment: .trailing)
        }.padding(.vertical, 15)
    }
    var auditView: some View { Surface { VStack(alignment: .leading, spacing: 14) { SectionHeading(title: "Registro delle attività", subtitle: "Cronologia locale. Non è un registro certificato o immodificabile."); ForEach(store.db.audit.reversed().prefix(200)) { a in HStack(alignment: .top) { Image(systemName: "clock").foregroundColor(Palette.teal); Text(a.label).font(.system(size: 12)); Spacer(); Text(a.date, format: .dateTime.day().month().hour().minute()).font(.system(size: 10)).foregroundColor(.secondary) }; Divider() }; if store.db.audit.isEmpty { Text("Le operazioni salvate compariranno qui.").foregroundColor(.secondary) } } } }
    func empty(_ title: String, _ description: String, _ icon: String) -> some View { VStack(spacing: 12) { Image(systemName: icon).font(.system(size: 30, weight: .light)).foregroundColor(Palette.teal.opacity(0.7)).padding(16).background(Palette.teal.opacity(0.05)).clipShape(Circle()); Text(title).font(.system(size: 15, weight: .semibold)); Text(description).font(.system(size: 11)).foregroundColor(.secondary).multilineTextAlignment(.center) }.frame(maxWidth: .infinity).padding(.vertical, 22) }
}
