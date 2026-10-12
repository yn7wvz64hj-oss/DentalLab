import SwiftUI
import AppKit

struct SharedSyncPanel: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @State private var path = ""
    @State private var password = ""
    @State private var issue = ""
    @State private var confirming = false
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("DISCO CONDIVISO · VPN", systemImage: "externaldrive.connected.to.line.below").font(.caption).foregroundColor(Palette.teal)
            Text("Il tuo archivio, tra casa e laboratorio").font(.title2.bold())
            Text("Collega la VPN e monta il disco nel Finder. Usa la stessa cartella e password sulle postazioni. La sessione resta riservata a questo computer fino alla chiusura di DentalLab.").font(.system(size: 13)).foregroundColor(.secondary)
            if store.sharedSession == nil {
                Field(title: "Cartella del disco montato", text: $path)
                Button("Scegli cartella…") { let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true; if panel.runModal() == .OK, let url = panel.url { path = url.path } }
                SecureField("Password condivisa · almeno 12 caratteri", text: $password).textFieldStyle(.roundedBorder)
            }
            if !issue.isEmpty { Text(issue).font(.caption).foregroundColor(.red) }
            HStack { Button("Chiudi") { dismiss() }.keyboardShortcut(.cancelAction); Spacer(); Button(store.sharedSession == nil ? "Collega e sincronizza" : "Pubblica aggiornamenti") {
                if let session = store.sharedSession { do { try session.publish(); dismiss() } catch { issue = error.localizedDescription }; return }
                let previous = try? JSONDecoder().decode(SharedArchiveSession.State.self, from: Data(contentsOf: store.folder.appendingPathComponent("sync-state.json")))
                if previous?.folder == URL(fileURLWithPath: path).standardizedFileURL.path { connect(false) } else { confirming = true }
            }.buttonStyle(LabButtonStyle(primary: true)) }
        }.padding(30).frame(width: 550).background { WorkspaceBackdrop() }.buttonStyle(LabButtonStyle())
        .onAppear { path = (try? String(contentsOf: store.sharedConfig, encoding: .utf8)) ?? "" }
        .sheet(isPresented: $confirming) {
            LabConfirmation(title: "Primo collegamento", message: "Se la cartella contiene già un archivio DentalLab, sostituirà quello di questa postazione dopo una copia preventiva locale. In una cartella nuova verrà pubblicato l’archivio attuale. Usa un solo computer alla volta.", actionTitle: "Collega archivio", cancel: { confirming = false }, action: { confirming = false; connect(true) })
        }
    }
    private func connect(_ initialize: Bool) {
        do { try require(!path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Scegli la cartella del disco montato."); try store.connectShared(folder: URL(fileURLWithPath: path), password: password, initialize: initialize); password = ""; dismiss() }
        catch { issue = error.localizedDescription; password = "" }
    }
}

final class SharedTerminationDelegate: NSObject, NSApplicationDelegate {
    weak var store: Store?
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let store = store else { return .terminateNow }
        if !store.editedDrafts.isEmpty { store.error = "Salva o chiudi le schede modificate prima di uscire da DentalLab."; return .terminateCancel }
        do { try store.finishShared(); return .terminateNow }
        catch { store.error = "Chiusura annullata. Le modifiche restano locali: ricollega VPN e disco, sblocca l’archivio e riprova. " + error.localizedDescription; return .terminateCancel }
    }
}
