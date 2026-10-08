import Foundation
import AppKit

struct DentalChartChecks {
    static func run() throws {
        try require(DentalSelection.valid.count == 52, "Elementi permanenti/decidui mancanti")
        let single = DentalSelection.click(11, selected: [18], anchor: nil, extend: false, range: false)
        try require(single == [11], "Selezione singola errata")
        let added = DentalSelection.click(21, selected: single, anchor: 11, extend: true, range: false)
        try require(added == [11,21], "Ctrl non aggiunge il dente")
        try require(DentalSelection.click(11, selected: added, anchor: 21, extend: true, range: false) == [21], "Ctrl non deseleziona")
        let range = DentalSelection.click(23, selected: [11], anchor: 11, extend: false, range: true)
        try require(range == [11,21,22,23], "Intervallo attraverso la linea mediana errato")
        try require(DentalSelection.click(48, selected: range, anchor: 11, extend: false, range: true) == [48], "Intervallo esteso tra arcate diverse")
        let old = [ToothWork(tooth: 16, kind: "Intarsio", shadeSystem: "VITA classical A1–D4", shade: "A1")]
        let result = DentalSelection.apply(old, selected: range, kind: "Ponte — pilastro", system: "VITA classical A1–D4", shade: "A3.5")
        try require(result.count == 5 && result.first(where: { $0.tooth == 16 }) == old[0], "Modificato un dente non selezionato")
        let replaced = DentalSelection.apply(result, selected: [11,21], kind: "Faccetta", system: "VITA 3D-MASTER", shade: "2M2")
        try require(replaced.count == 5 && replaced.first(where: { $0.tooth == 11 })?.shade == "2M2", "Sostituzione o codice colore errati")
        var device = Device(); device.toothWorks = replaced
        let restored = try JSONDecoder().decode(Device.self, from: JSONEncoder().encode(device))
        try require(restored == device && restored.toothWorks?.count == 5, "Mappa non persistita")
        var oldDevice = try JSONSerialization.jsonObject(with: JSONEncoder().encode(Device())) as! [String: Any]
        oldDevice.removeValue(forKey: "toothWorks")
        try require(try JSONDecoder().decode(Device.self, from: JSONSerialization.data(withJSONObject: oldDevice)).toothWorks == nil, "Migrazione dispositivo precedente fallita")
        try require(DentalSelection.shades.count == 16 && DentalSelection.shades.contains("A3.5") && !DentalSelection.shades.contains("D1"), "Codici VITA classical errati")
        try require(DentalSelection.summary(replaced).contains("2M2"), "Colore mancante nel riepilogo PDF")
        var cleared = Device(); cleared.teeth = "11"; cleared.shade = "A1"; cleared.toothWorks = []
        try require(cleared.dentalElements.isEmpty && cleared.dentalShades.isEmpty, "Rimozione mappa riutilizza dati precedenti")
        let hit = ToothHitView(); var captured: NSEvent.ModifierFlags = []
        hit.action = { captured = $0 }
        let controlEvent = NSEvent.mouseEvent(with: .rightMouseDown, location: .zero, modifierFlags: .control, timestamp: 0, windowNumber: 0, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)!
        hit.rightMouseDown(with: controlEvent)
        try require(captured.contains(.control), "Ctrl+clic non consegnato alla selezione")
        let shiftEvent = NSEvent.mouseEvent(with: .leftMouseDown, location: .zero, modifierFlags: .shift, timestamp: 0, windowNumber: 0, context: nil, eventNumber: 2, clickCount: 1, pressure: 1)!
        hit.mouseDown(with: shiftEvent)
        try require(captured.contains(.shift), "Maiuscolo+clic non consegnato alla selezione")
        var entry = Entry(section: "Lavori"); entry.name = "Prova mappa"; entry.device = device
        try Validation.basic(entry)
        try require(Documents.blocks(entry, db: Database()).contains { $0.text.contains("2M2") && $0.text.contains("Faccetta") }, "Lavorazione o colore assenti nel PDF")
        entry.device?.toothWorks?.append(replaced[0]); var rejected = false
        do { try Validation.basic(entry) } catch { rejected = true }
        try require(rejected, "Dente duplicato accettato")
        print("PASS · selezione singola/Ctrl/Maiuscolo, arcate, assegnazione multipla, sostituzione, codici VITA, persistenza e migrazione mappa")
    }
}
