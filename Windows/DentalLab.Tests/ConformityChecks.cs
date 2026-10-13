using DentalLab.Core;
using System.Text.Json.Nodes;

static class ConformityChecks
{
    public static int Run(string root,byte[] key)
    {
        int count=0;void Check(bool value){if(!value)throw new Exception("Conformity check failed.");count++;}
        void Reject(Action action){bool refused=false;try{action();}catch{refused=true;}Check(refused);}
        using var archive=new LocalArchive(Path.Combine(root,"conformity"),key);
        var work=JsonNode.Parse("""
        {"id":"00000000-0000-4000-8000-000000000001","section":"Lavori","name":"Ponte prova","client":"Studio di prova","patient":"P-042","detail":"Note sintetiche","status":"Pronto","date":812345678,"price":0,"quantity":0,"lot":"LOT-1","paid":false,"attachments":[],"device":{"identifier":"DL-1","type":"Protesi fissa","riskClass":"IIa","implantable":false,"prescriber":"Dr. Test","institution":"Studio","prescription":"Prescrizione","prescriptionDate":812345678,"releaseDate":812345678,"requirements":"Verifica requisiti","conformityConfirmed":true,"substances":"Non applicabili","design":"Disegno","manufacturing":"Produzione","performance":"Prestazioni","risks":"Valutazione rischi","checks":"Controlli","instructions":"Istruzioni","reviewer":"Responsabile","toothWorks":[{"tooth":11,"kind":"Ponte — pilastro","shadeSystem":"VITA classical A1–D4","shade":"A2"},{"tooth":21,"kind":"Faccetta","shadeSystem":"VITA 3D-MASTER","shade":"2M2"}]}}
        """)!.AsObject();
        var draft=Conformity.Draft(work);Check(Conformity.Text(draft,"workID")==Conformity.Text(work,"id"));Check(Conformity.Text(draft,"id")!=Conformity.Text(work,"id"));
        draft["device"]!["toothWorks"]![0]!["shade"]="A3";Check(Conformity.Text(work["device"]!["toothWorks"]![0],"shade")=="A2");
        var profile=(JsonObject)archive.Database["profile"]!.DeepClone();profile["name"]="Laboratorio àèìòù";profile["contact"]!["address"]="Via Prova 1";profile["productionSites"]="Via Prova 1";
        Reject(()=>Conformity.Save(archive,draft,profile,true));Check(archive.Database["counters"]!.AsObject().Count==0);
        string file=LocalArchive.NewID();archive.SaveBlob(file,"Prescrizione sintetica"u8.ToArray());draft["files"]=new JsonArray(new JsonObject{["id"]=file,["name"]="Prescrizione.txt",["category"]="Prescrizione"});
        Conformity.Save(archive,draft,profile);Check(archive.Database["entries"]!.AsArray().Count==1);Check(archive.Database["entries"]![0]!["issued"]==null);
        Check(Conformity.Blocks(draft,archive.Database).Any(b=>b.Text.Contains("2M2")&&b.Text.Contains("Faccetta")));
        Conformity.Save(archive,draft,profile,true);var issued=archive.Database["entries"]![0]!.AsObject();Check(Conformity.Text(issued["issued"],"number").EndsWith("0001"));
        Reject(()=>Conformity.Save(archive,draft,profile,true));Reject(()=>Conformity.Save(archive,draft,profile));
        var changed=(JsonObject)archive.Database.DeepClone();changed["profile"]!["name"]="Nome nuovo";archive.Save(changed);Check(Conformity.Blocks(issued,archive.Database).Any(b=>b.Text.Contains("Laboratorio àèìòù")));
        var version=Conformity.Draft(work);version["files"]=draft["files"]!.DeepClone();Conformity.Save(archive,version,profile,true);Check(Conformity.Text(archive.Database["entries"]![1]!["issued"],"number").EndsWith("0002"));
        version=Conformity.Draft(work);version["files"]=draft["files"]!.DeepClone();version["device"]!["implantable"]=true;version["device"]!["riskClass"]="III";Reject(()=>Conformity.Save(archive,version,profile,true));
        return count;
    }
}
