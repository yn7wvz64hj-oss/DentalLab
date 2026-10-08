import SwiftUI
import EventKit

struct CalendarLink: Codable {
    var calendarID: String
    var owner = UUID()
    var automatic = false
    var lastSync: Date?
    var events: [String: String] = [:]
}
struct Deadline {
    let id: UUID
    let start: Date
    let end: Date
    var title: String { "DentalLab · Consegna DL-" + id.uuidString.prefix(8) }
    static func make(_ entries: [Entry]) -> [Deadline] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Rome")!
        return entries.filter { $0.section == "Lavori" && !$0.isArchived && $0.status != "Consegnato" }.map {
            let start = calendar.startOfDay(for: $0.date)
            return Deadline(id: $0.id, start: start, end: calendar.date(byAdding: .day, value: 1, to: start)!)
        }
    }
}
final class CalendarBridge: ObservableObject {
    private let eventStore = EKEventStore()
    @Published var calendars: [EKCalendar] = []
    @Published var message = ""
    @Published var busy = false
    private var pending: DispatchWorkItem?
    var allowed: Bool { EKEventStore.authorizationStatus(for: .event) == .authorized }
    func connect() {
        let completion: @convention(block) (Bool, NSError?) -> Void = { granted, error in
            DispatchQueue.main.async { self.message = granted ? "Scegli il calendario Google dall’elenco." : (error?.localizedDescription ?? "Accesso negato. Abilita DentalLab in Impostazioni di Sistema → Privacy e sicurezza → Calendari."); self.refresh() }
        }
        // The modern API is resolved at runtime so builds with the macOS 13 SDK also support macOS 14+.
        let selector = NSSelectorFromString("requestFullAccessToEventsWithCompletion:")
        if eventStore.responds(to: selector) {
            typealias Request = @convention(c) (AnyObject, Selector, @convention(block) (Bool, NSError?) -> Void) -> Void
            let request = unsafeBitCast(eventStore.method(for: selector), to: Request.self)
            request(eventStore, selector, completion)
        } else { eventStore.requestAccess(to: .event) { granted, error in completion(granted, error as NSError?) } }
    }
    func refresh() {
        calendars = allowed ? eventStore.calendars(for: .event).filter { $0.allowsContentModifications }.sorted { ($0.source.title + $0.title) < ($1.source.title + $1.title) } : []
    }
    func queue(_ store: Store) {
        pending?.cancel()
        guard store.db.calendarLink?.automatic == true else { return }
        let task = DispatchWorkItem { [weak self, weak store] in if let store = store { self?.sync(store) } }
        pending = task; DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: task)
    }
    func sync(_ store: Store) {
        guard store.ready && !store.locked && !busy, var link = store.db.calendarLink else { return }
        guard allowed else { message = "Sincronizzazione in attesa: autorizza l’accesso ai calendari."; return }
        guard let calendar = eventStore.calendar(withIdentifier: link.calendarID), calendar.allowsContentModifications else { message = "Calendario non disponibile. Ricollegalo nelle impostazioni."; return }
        busy = true; defer { busy = false }
        do {
            let deadlines = Deadline.make(store.entries)
            let prefix = "dentallab://" + link.owner.uuidString + "/"
            var owned: [String: EKEvent] = [:]
            // Identifier lookup handles past and far-future events; URL lookup recovers identifiers changed by the provider.
            for (id, identifier) in link.events {
                if let event = eventStore.event(withIdentifier: identifier), event.calendar.calendarIdentifier == link.calendarID, event.url?.absoluteString == prefix + id { owned[id] = event }
            }
            let dates = deadlines.map { $0.start } + owned.values.map { $0.startDate! } + [Date()]
            let lower = dates.min()!.addingTimeInterval(-86400 * 7)
            let upper = dates.max()!.addingTimeInterval(86400 * 7)
            var cursor = lower
            // EventKit search windows must be smaller than four years.
            while cursor < upper {
                let end = min(cursor.addingTimeInterval(86400 * 365), upper)
                for event in eventStore.events(matching: eventStore.predicateForEvents(withStart: cursor, end: end, calendars: [calendar])) {
                    if let url = event.url?.absoluteString, url.hasPrefix(prefix), UUID(uuidString: String(url.dropFirst(prefix.count))) != nil {
                        let id = String(url.dropFirst(prefix.count))
                        if let existing = owned[id], existing.eventIdentifier != event.eventIdentifier { try eventStore.remove(event, span: .thisEvent, commit: false) }
                        else { owned[id] = event }
                    }
                }
                cursor = end
            }
            let active = Set(deadlines.map { $0.id.uuidString })
            for (id, event) in owned where !active.contains(id) { try eventStore.remove(event, span: .thisEvent, commit: false) }
            var saved: [(String, EKEvent)] = []
            for deadline in deadlines {
                let id = deadline.id.uuidString
                let event = owned[id] ?? EKEvent(eventStore: eventStore)
                event.calendar = calendar; event.title = deadline.title; event.isAllDay = true
                event.startDate = deadline.start; event.endDate = deadline.end; event.timeZone = TimeZone(identifier: "Europe/Rome")
                event.url = URL(string: prefix + id); event.notes = nil; event.location = nil; event.alarms = nil
                try eventStore.save(event, span: .thisEvent, commit: false)
                saved.append((id, event))
            }
            try eventStore.commit()
            link.events = Dictionary(uniqueKeysWithValues: saved.compactMap { id, event in event.eventIdentifier.map { (id, $0) } })
            link.lastSync = Date()
            if store.commit("Scadenze aggiornate nel calendario", update: { $0.calendarLink = link }) {
                message = "\(deadlines.count) consegne aggiornate nel Calendario del Mac. L’account Google viene sincronizzato da macOS."
            } else { message = "Calendario aggiornato; stato locale non salvato. Ripeti la sincronizzazione per recuperarlo." }
        } catch { eventStore.reset(); message = "Sincronizzazione non riuscita: " + error.localizedDescription }
    }
}
struct CalendarPanel: View {
    @ObservedObject var store: Store
    @ObservedObject var bridge: CalendarBridge
    @State private var selected = ""
    @State private var automatic = false
    @State private var confirm = false
    init(store: Store) { self.store = store; self.bridge = store.calendarBridge }
    var body: some View {
        Surface { VStack(alignment: .leading, spacing: 14) {
            SectionHeading(title: "Google Calendar", subtitle: "Usa l’account Google già aggiunto a Calendario sul Mac.")
            Text("Invia solo codice lavoro e data di consegna, per l’intera giornata. Nomi, pazienti e dettagli clinici restano nell’archivio. Scegli preferibilmente un calendario Google dedicato a DentalLab.").font(.caption).foregroundColor(.secondary)
            HStack { Button("Autorizza calendari") { bridge.connect() }; Button("Aggiorna elenco") { bridge.refresh() } }
            Picker("Calendario", selection: $selected) {
                Text("Seleziona un calendario").tag("")
                ForEach(bridge.calendars, id: \.calendarIdentifier) { Text($0.source.title + " · " + $0.title).tag($0.calendarIdentifier) }
            }
            Toggle("Aggiorna automaticamente quando salvo un lavoro", isOn: $automatic)
            Text("\(Deadline.make(store.entries).count) consegne da sincronizzare. Le modifiche in Google Calendar non vengono importate nell’app.").font(.caption)
            HStack {
                Button("Collega e sincronizza") { confirm = true }.disabled(selected.isEmpty || bridge.busy || !bridge.allowed)
                if store.db.calendarLink != nil {
                    Button("Sincronizza ora") { bridge.sync(store) }.disabled(bridge.busy)
                    Button("Disattiva automatico") { _ = store.commit("Calendario scollegato", update: { $0.calendarLink?.automatic = false }); automatic = false; bridge.message = "Aggiornamenti automatici disattivati. Puoi ancora sincronizzare manualmente." }
                }
            }
            if let last = store.db.calendarLink?.lastSync { Text("Ultimo aggiornamento locale: " + last.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundColor(.secondary) }
            if !bridge.message.isEmpty { Text(bridge.message).font(.caption).foregroundColor(Palette.teal) }
        } }.onAppear { bridge.refresh(); selected = store.db.calendarLink?.calendarID ?? ""; automatic = store.db.calendarLink?.automatic ?? false }
        .alert("Conferma sincronizzazione", isPresented: $confirm) {
            Button("Annulla", role: .cancel) {}
            Button("Conferma") {
                var link = store.db.calendarLink ?? CalendarLink(calendarID: selected)
                if link.calendarID != selected { link = CalendarLink(calendarID: selected) }
                link.automatic = automatic
                if store.commit("Collegamento calendario configurato", update: { $0.calendarLink = link }) { bridge.sync(store) }
            }
        } message: {
            Text("Calendario: \(bridge.calendars.first { $0.calendarIdentifier == selected }.map { $0.source.title + " · " + $0.title } ?? selected). Verranno creati o aggiornati eventi con codice e data. Gli eventi creati da questo collegamento saranno rimossi quando il lavoro è consegnato o archiviato. Gli altri eventi restano invariati. Cambiando calendario, le vecchie copie restano nel calendario precedente.")
        }
    }
}
