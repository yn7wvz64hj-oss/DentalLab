import SwiftUI
import AppKit

@main struct DentalLabApp: App {
    @StateObject private var store: Store
    init() {
        if CommandLine.arguments.contains("--self-test") { do { try SelfTests.run(); exit(0) } catch { fputs("TEST FAILED: \(error)\n", stderr); exit(1) } }
        if let i = CommandLine.arguments.firstIndex(of: "--preview"), CommandLine.arguments.count > i + 1 { PreviewRenderer.run(to: CommandLine.arguments[i + 1]); exit(0) }
        _store = StateObject(wrappedValue: Store())
        NSApplication.shared.setActivationPolicy(.regular)
        AppUpdates.shared.start()
    }
    var body: some Scene {
        WindowGroup { ContentView().environmentObject(store).onAppear { store.calendarBridge.queue(store) }.frame(minWidth: 1080, minHeight: 700).tint(Palette.teal).labelStyle(.titleAndIcon).buttonStyle(LabButtonStyle()).preferredColorScheme(.light) }
        .windowStyle(.hiddenTitleBar)
        .commands { CommandGroup(after: .appInfo) { UpdateMenuItem() }; CommandGroup(after: .saveItem) { Button("Blocca archivio") { store.lock() }.keyboardShortcut("l", modifiers: [.command, .shift]) } }
    }
}

struct UpdateMenuItem: View {
    @ObservedObject private var updates = AppUpdates.shared
    var body: some View { Button("Cerca aggiornamenti…") { updates.check() }.disabled(!updates.canCheck) }
}
