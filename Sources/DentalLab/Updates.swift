import SwiftUI
import Sparkle

final class AppUpdates: ObservableObject {
    static let shared = AppUpdates()
    private let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
    @Published var canCheck = false
    @Published var automatic = false
    @Published var started = false
    var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.4.0" }
    func start() {
        guard !started, Bundle.main.bundleURL.pathExtension == "app" else { return }
        started = true
        controller.updater.publisher(for: \.canCheckForUpdates).receive(on: DispatchQueue.main).assign(to: &$canCheck)
        controller.startUpdater()
        automatic = controller.updater.automaticallyChecksForUpdates
    }
    func check() { start(); if canCheck { controller.checkForUpdates(nil) } }
    func setAutomatic(_ value: Bool) { controller.updater.automaticallyChecksForUpdates = value; automatic = value }
}
struct UpdatesPanel: View {
    @ObservedObject private var updates = AppUpdates.shared
    var body: some View {
        Surface { VStack(alignment: .leading, spacing: 14) {
            HStack { BrandMark().frame(width: 34, height: 40); SectionHeading(title: "Aggiornamenti DentalLab", subtitle: "Versione " + updates.version) }
            Text("Controlla le nuove versioni pubblicate su GitHub e installale dall’app. Il pacchetto viene verificato con una firma digitale prima dell’installazione. Salva le schede aperte ed esporta un backup prima di aggiornare.").font(.caption).foregroundColor(.secondary)
            HStack {
                Button("Cerca aggiornamenti…") { updates.check() }.disabled(!updates.canCheck)
                Link("Versioni su GitHub", destination: URL(string: "https://github.com/yn7wvz64hj-oss/DentalLab/releases")!)
            }
            Toggle("Controlla automaticamente la disponibilità di nuove versioni", isOn: Binding(get: { updates.automatic }, set: { updates.setAutomatic($0) })).disabled(!updates.started)
            Text("Il controllo contatta GitHub; l’archivio del laboratorio non viene inviato. Sparkle mostra le novità e richiede la conferma per installare e riavviare. Installa prima DentalLab in una cartella scrivibile, per esempio Applicazioni nel tuo account.").font(.caption).foregroundColor(.secondary)
        } }
    }
}
