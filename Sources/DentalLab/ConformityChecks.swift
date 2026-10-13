import Foundation
import CryptoKit
import PDFKit

struct ConformityChecks {
    static func run() throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("Conformity-check-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store=Store(folder: root,testKey: SymmetricKey(size: .bits256))
        var work=store.create("Lavori");work.name="Ponte prova";work.patient="P-042";work.device?.toothWorks=[ToothWork(tooth: 11,kind: "Ponte — pilastro",shadeSystem: "VITA classical A1–D4",shade: "A2"),ToothWork(tooth: 21,kind: "Faccetta",shadeSystem: "VITA 3D-MASTER",shade: "2M2")]
        try require(store.save(work),store.error)
        guard let document=store.conformity(for: work) else { throw AppIssue(message: store.error) }
        try require(document.workID==work.id && document.device==work.device,"Collegamento o dati della dichiarazione mancanti")
        try require(store.conformity(for: work)?.id==document.id,"Dichiarazione duplicata al secondo clic")
        guard let version=store.conformity(for: work,forceNew: true) else { throw AppIssue(message: store.error) }
        try require(version.id != document.id && version.workID==work.id,"Nuova versione non indipendente")
        var edited=version;edited.device?.toothWorks?[0].shade="A3"
        try require(work.device?.toothWorks?[0].shade=="A2","La dichiarazione modifica il lavoro")
        edited.device?.instructions=String(repeating:"Istruzioni sintetiche àèìòù per il paziente. ",count:350)
        let pdf=root.appendingPathComponent("conformita.pdf");try Documents.pdf(edited,db: store.db,to:pdf)
        guard let rendered=PDFDocument(url:pdf) else { throw AppIssue(message:"PDF dichiarazione non leggibile") }
        try require(rendered.pageCount>1 && (rendered.string ?? "").contains("2M2") && (rendered.string ?? "").contains("BOZZA"),"PDF multipagina o lavorazioni mancanti")
        print("PASS · conformità dalla scheda: collegamento, riapertura, versioni indipendenti, denti e PDF multipagina")
    }
}
