import SwiftUI

// Keep the platform menu behavior, keyboard navigation and selection bindings.
struct LabPicker<Selection: Hashable, Content: View>: View {
    let title: String
    @Binding var selection: Selection
    let content: Content
    init(_ title: String, selection: Binding<Selection>, @ViewBuilder content: () -> Content) {
        self.title = title; _selection = selection; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
            Picker(title, selection: $selection) { content }.labelsHidden().pickerStyle(.menu)
                .controlSize(.large).frame(maxWidth: .infinity, alignment: .leading)
                .padding(8).background(Color.white).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.line))
        }
    }
}

struct LabConfirmation: View {
    let title: String
    let message: String
    var actionTitle = "Conferma"
    var cancelTitle = "Annulla"
    let cancel: () -> Void
    let action: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Label("DENTALLAB · CONFERMA", systemImage: "checkmark.shield").font(.system(size: 11, weight: .semibold)).foregroundColor(Palette.teal)
            Text(title).font(.system(size: 25, weight: .semibold))
            Surface { Text(message).font(.system(size: 14)).lineSpacing(6).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading) }
            HStack { Button(cancelTitle, action: cancel).keyboardShortcut(.cancelAction); Spacer(); Button(actionTitle, action: action).buttonStyle(LabButtonStyle(primary: true)) }
        }.padding(30).frame(width: 510).background { WorkspaceBackdrop() }.buttonStyle(LabButtonStyle()).tint(Palette.teal)
    }
}

extension View {
    func labAlert<Actions: View, Message: View>(_ title: String, isPresented: Binding<Bool>, @ViewBuilder actions: @escaping () -> Actions, @ViewBuilder message: @escaping () -> Message) -> some View {
        sheet(isPresented: isPresented) {
            VStack(alignment: .leading, spacing: 22) {
                Label("DENTALLAB", systemImage: "info.circle").font(.system(size: 11, weight: .semibold)).foregroundColor(Palette.teal)
                Text(title).font(.system(size: 25, weight: .semibold))
                Surface { message().font(.system(size: 14)).lineSpacing(6).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading) }
                HStack(spacing: 12) { Spacer(); actions() }
            }.padding(30).frame(width: 510).background { WorkspaceBackdrop() }.buttonStyle(LabButtonStyle()).tint(Palette.teal).onExitCommand { isPresented.wrappedValue = false }
        }
    }
}
