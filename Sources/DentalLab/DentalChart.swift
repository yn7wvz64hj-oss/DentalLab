import SwiftUI
import AppKit

struct ToothWork: Codable, Equatable, Identifiable {
    var tooth: Int
    var kind: String
    var shadeSystem: String
    var shade: String
    var id: Int { tooth }
}
struct DentalSelection {
    static let upper = [18,17,16,15,14,13,12,11,21,22,23,24,25,26,27,28]
    static let lower = [48,47,46,45,44,43,42,41,31,32,33,34,35,36,37,38]
    static let primaryUpper = [55,54,53,52,51,61,62,63,64,65]
    static let primaryLower = [85,84,83,82,81,71,72,73,74,75]
    static let valid = Set(upper + lower + primaryUpper + primaryLower)
    static let shades = ["A1","A2","A3","A3.5","A4","B1","B2","B3","B4","C1","C2","C3","C4","D2","D3","D4"]
    static func click(_ tooth: Int, selected: Set<Int>, anchor: Int?, extend: Bool, range: Bool) -> Set<Int> {
        if range, let anchor = anchor, let arch = [upper,lower,primaryUpper,primaryLower].first(where: { $0.contains(anchor) && $0.contains(tooth) }), let a = arch.firstIndex(of: anchor), let b = arch.firstIndex(of: tooth) {
            return selected.union(arch[min(a,b)...max(a,b)])
        }
        if extend { var next = selected; if next.contains(tooth) { next.remove(tooth) } else { next.insert(tooth) }; return next }
        return [tooth]
    }
    static func apply(_ old: [ToothWork], selected: Set<Int>, kind: String, system: String, shade: String) -> [ToothWork] {
        (old.filter { !selected.contains($0.tooth) } + selected.sorted().map { ToothWork(tooth: $0, kind: kind, shadeSystem: system, shade: shade) }).sorted { $0.tooth < $1.tooth }
    }
    static func summary(_ works: [ToothWork]) -> String {
        works.sorted { $0.tooth < $1.tooth }.map { "\($0.tooth): \($0.kind) · \($0.shadeSystem) \($0.shade)" }.joined(separator: "\n")
    }
}
struct ToothClick: NSViewRepresentable {
    var label: String
    var action: (NSEvent.ModifierFlags) -> Void
    func makeNSView(context: Context) -> ToothHitView { ToothHitView() }
    func updateNSView(_ view: ToothHitView, context: Context) { view.action = action; view.setAccessibilityElement(true); view.setAccessibilityRole(.button); view.setAccessibilityLabel(label) }
}
final class ToothHitView: NSView {
    var action: ((NSEvent.ModifierFlags) -> Void)?
    override var acceptsFirstResponder: Bool { true }
    override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self); action?(event.modifierFlags) }
    override func rightMouseDown(with event: NSEvent) { if event.modifierFlags.contains(.control) { action?(event.modifierFlags) } }
    override func keyDown(with event: NSEvent) { if event.keyCode == 49 || event.keyCode == 36 { action?(event.modifierFlags) } else { super.keyDown(with: event) } }
    override func accessibilityPerformPress() -> Bool { action?([]); return true }
}
struct DentalChart: View {
    @Binding var works: [ToothWork]
    @State private var selected: Set<Int> = []
    @State private var anchor: Int?
    @State private var primary = false
    @State private var kind = "Corona in zirconia"
    @State private var system = "VITA classical A1–D4"
    @State private var shade = "A2"
    @State private var customShade = ""
    @State private var customKind = ""
    @State private var issue = ""
    @State private var removing = false
    let readOnly: Bool
    var upper: [Int] { primary ? DentalSelection.primaryUpper : DentalSelection.upper }
    var lower: [Int] { primary ? DentalSelection.primaryLower : DentalSelection.lower }
    var body: some View {
        Surface { VStack(alignment: .leading, spacing: 14) {
            SectionHeading(title: "Mappa dentale", subtitle: "Clic: un dente · Ctrl o ⌘: aggiungi/togli · Maiuscolo: intervallo nella stessa arcata.")
            HStack { Toggle("Dentizione decidua", isOn: $primary).onChange(of: primary) { _ in selected = []; anchor = nil }; Spacer(); Text("Destra del paziente ← → Sinistra del paziente").font(.caption).foregroundColor(.secondary) }
            GeometryReader { geometry in
                let width = geometry.size.width
                ZStack {
                    Text("ARCATA SUPERIORE\n\n\nARCATA INFERIORE").font(.system(size: 10, weight: .semibold)).tracking(1.4).foregroundColor(.secondary).multilineTextAlignment(.center).position(x: width / 2, y: 190)
                    arch(upper, width: width, upperArch: true)
                    arch(lower, width: width, upperArch: false)
                }
            }.frame(height: 370)
            HStack { Circle().fill(Palette.teal).frame(width: 8,height: 8); Text("Selezionato"); Circle().fill(Color.orange).frame(width: 8,height: 8); Text("Lavorazione assegnata"); Spacer(); Text(selected.sorted().map(String.init).joined(separator: ", ")).fontWeight(.semibold) }.font(.caption)
            if !readOnly {
                HStack {
                    Picker("Lavorazione", selection: $kind) { ForEach(["Corona in zirconia","Corona metallo-ceramica","Corona in disilicato","Ponte — pilastro","Ponte — elemento intermedio","Faccetta","Intarsio","Protesi mobile","Bite","Ortodonzia","Riparazione","Altro"], id: \.self) { Text($0).tag($0) } }
                    Picker("Scala colore", selection: $system) { Text("VITA classical A1–D4").tag("VITA classical A1–D4"); Text("VITA 3D-MASTER").tag("VITA 3D-MASTER"); Text("Altra scala").tag("Altra scala") }
                    if system == "VITA classical A1–D4" { Picker("Colore", selection: $shade) { ForEach(DentalSelection.shades, id: \.self) { Text($0).tag($0) } } }
                    else { TextField("Codice colore", text: $customShade).textFieldStyle(.roundedBorder) }
                }
                if kind == "Altro" { Field(title: "Descrivi la lavorazione", text: $customKind) }
                HStack {
                    Button("Applica ai denti selezionati") { apply() }.buttonStyle(LabButtonStyle(primary: true)).disabled(selected.isEmpty)
                    Button("Rimuovi lavorazioni selezionate") { removing = true }.disabled(selected.isEmpty || !works.contains { selected.contains($0.tooth) })
                    Button("Deseleziona") { selected = []; anchor = nil }
                }
                Text("Per estendere una lavorazione: seleziona il dente già compilato, aggiungi gli altri con Ctrl oppure Maiuscolo, poi premi Applica. Il pulsante sostituisce le assegnazioni dei denti selezionati; la scheda viene registrata con Salva bozza.").font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                Text("Il codice VITA è un dato di registrazione. La grafica non rappresenta una scala cromatica calibrata.").font(.caption).foregroundColor(.secondary)
            }
            if !issue.isEmpty { Text(issue).font(.caption).foregroundColor(.red) }
            if !works.isEmpty { Divider(); ForEach(works.sorted { $0.tooth < $1.tooth }) { work in HStack { Text(String(work.tooth)).font(.system(size: 12,weight: .bold)).frame(width: 30); Text(work.kind).font(.caption); Spacer(); Text(work.shadeSystem + " · " + work.shade).font(.caption).foregroundColor(.secondary) } } }
        } }.alert("Rimuovere le lavorazioni?", isPresented: $removing) { Button("Annulla", role: .cancel) {}; Button("Rimuovi", role: .destructive) { works.removeAll { selected.contains($0.tooth) } } } message: { Text("Verranno eliminate solo le assegnazioni dei denti selezionati, dopo il salvataggio della scheda.") }
    }
    func arch(_ teeth: [Int], width: CGFloat, upperArch: Bool) -> some View {
        ForEach(Array(teeth.enumerated()), id: \.element) { index, tooth in
            let spread = CGFloat(index) / CGFloat(teeth.count - 1)
            let curve = pow(abs(spread * 2 - 1), 1.6) * 105
            let y = upperArch ? 38 + curve : 330 - curve
            let assigned = works.first { $0.tooth == tooth }
            VStack(spacing: 2) {
                Text(String(tooth)).font(.system(size: 10,weight: .semibold))
                ToothMark().fill(selected.contains(tooth) ? Palette.teal : assigned != nil ? Color.orange.opacity(0.7) : Color.white).overlay(ToothMark().stroke(Palette.teal.opacity(0.45), lineWidth: 1.2)).frame(width: 36, height: 44).rotationEffect(upperArch ? .degrees(0) : .degrees(180))
                Text(assigned?.shade ?? "—").font(.system(size: 8)).foregroundColor(.secondary)
            }.frame(width: 42, height: 70).background(selected.contains(tooth) ? Palette.teal.opacity(0.08) : Color.clear).cornerRadius(8)
            .overlay(ToothClick(label: "Dente \(tooth), \(assigned?.kind ?? "nessuna lavorazione"), \(assigned?.shade ?? "nessun colore")", action: { flags in choose(tooth, flags: flags) }))
            .help("Dente \(tooth) · \(assigned?.kind ?? "Nessuna lavorazione")")
            .position(x: 25 + spread * (width - 50), y: y)
        }
    }
    func choose(_ tooth: Int, flags: NSEvent.ModifierFlags) {
        let extending = flags.contains(.control) || flags.contains(.command)
        let ranging = flags.contains(.shift)
        selected = DentalSelection.click(tooth, selected: selected, anchor: anchor, extend: extending, range: ranging)
        if !ranging { anchor = tooth }
        if !extending && !ranging, let work = works.first(where: { $0.tooth == tooth }) {
            let known = ["Corona in zirconia","Corona metallo-ceramica","Corona in disilicato","Ponte — pilastro","Ponte — elemento intermedio","Faccetta","Intarsio","Protesi mobile","Bite","Ortodonzia","Riparazione"]
            kind = known.contains(work.kind) ? work.kind : "Altro"; customKind = work.kind; system = work.shadeSystem
            if system == "VITA classical A1–D4" { shade = work.shade } else { customShade = work.shade }
        }
    }
    func apply() {
        let chosenKind = (kind == "Altro" ? customKind : kind).trimmingCharacters(in: .whitespacesAndNewlines)
        let chosenShade = (system == "VITA classical A1–D4" ? shade : customShade).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !chosenKind.isEmpty && !chosenShade.isEmpty else { issue = "Inserisci lavorazione e codice colore."; return }
        works = DentalSelection.apply(works, selected: selected, kind: chosenKind, system: system, shade: chosenShade); issue = ""
    }
}
