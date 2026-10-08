import SwiftUI
import CryptoKit

struct DailyAccess: Codable {
    var salt: Data
    var verifier: Data
    var lastDay: String?
    static func make(_ password: String) throws -> DailyAccess {
        try require(password.count >= 10, "Usa una password di almeno 10 caratteri.")
        let salt = try Vault.random(16)
        let key = try Vault.passwordKey(password, salt: salt)
        return DailyAccess(salt: salt, verifier: key.withUnsafeBytes { Data($0) })
    }
    func accepts(_ password: String) throws -> Bool {
        guard !password.isEmpty, salt.count == 16, verifier.count == 32 else { return false }
        let key = try Vault.passwordKey(password, salt: salt)
        let candidate = key.withUnsafeBytes { Data($0) }
        var difference: UInt8 = 0
        for (a, b) in zip(candidate, verifier) { difference |= a ^ b }
        return difference == 0
    }
    static func today(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = .current
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
    func requiresPassword(at date: Date) -> Bool { lastDay != Self.today(date) }
}
struct WorkYear {
    static func of(_ entry: Entry) -> Int {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Europe/Rome")!
        return calendar.component(.year, from: entry.date)
    }
    static func available(_ entries: [Entry]) -> [Int] {
        Array(Set(entries.filter { $0.section == "Lavori" }.map(of))).sorted(by: >)
    }
}
struct AccessScreen: View {
    @ObservedObject var store: Store
    @State private var password = ""
    @State private var confirmation = ""
    @State private var issue = ""
    var body: some View {
        VStack(spacing: 20) {
            BrandMark().frame(width: 70, height: 80)
            Text(store.needsPasswordSetup ? "Proteggi DentalLab" : "Bentornato in laboratorio").font(.title.bold())
            Text(store.needsPasswordSetup ? "Scegli una password: verrà richiesta al primo avvio di ogni giornata." : "Inserisci la password per aprire l’archivio. Dopo questo accesso puoi riaprire l’app durante la giornata.").font(.system(size: 13)).foregroundColor(.secondary).multilineTextAlignment(.center)
            SecureField("Password", text: $password).textFieldStyle(.roundedBorder).onSubmit { submit() }
            if store.needsPasswordSetup { SecureField("Ripeti la password", text: $confirmation).textFieldStyle(.roundedBorder).onSubmit { submit() }; Text("Almeno 10 caratteri. Conserva la password: non è recuperabile dall’app.").font(.caption).foregroundColor(.secondary) }
            if !issue.isEmpty { Text(issue).font(.caption).foregroundColor(.red) }
            Button(store.needsPasswordSetup ? "Imposta password e apri" : "Apri archivio") { submit() }.buttonStyle(LabButtonStyle(primary: true))
        }.frame(width: 380).padding(36).background(Color.white).cornerRadius(22)
    }
    func submit() {
        do {
            if store.needsPasswordSetup { try require(password == confirmation, "Le password non coincidono."); try store.setDailyPassword(password) }
            else { try store.unlockWithPassword(password) }
            password = ""; confirmation = ""; issue = ""
        } catch { password = ""; confirmation = ""; issue = error.localizedDescription }
    }
}
struct PasswordPanel: View {
    @ObservedObject var store: Store
    @State private var current = ""
    @State private var newPassword = ""
    @State private var confirmation = ""
    @State private var issue = ""
    var body: some View {
        Surface { VStack(alignment: .leading, spacing: 14) {
            SectionHeading(title: "Password giornaliera", subtitle: "Richiesta al primo avvio di ogni giorno, secondo la data del Mac.")
            Text("Il lucchetto blocca subito l’app e richiede nuovamente la password. La password di accesso è distinta da quella dei backup; l’archivio resta cifrato con la chiave nel Portachiavi del Mac.").font(.caption).foregroundColor(.secondary)
            HStack { SecureField("Password attuale", text: $current); SecureField("Nuova password", text: $newPassword); SecureField("Ripeti nuova password", text: $confirmation) }.textFieldStyle(.roundedBorder)
            Button("Cambia password") {
                do { try require(newPassword == confirmation, "Le password non coincidono."); try store.changeDailyPassword(current: current, new: newPassword); issue = "Password aggiornata." }
                catch { issue = error.localizedDescription }
                current = ""; newPassword = ""; confirmation = ""
            }
            if !issue.isEmpty { Text(issue).font(.caption) }
        } }
    }
}
