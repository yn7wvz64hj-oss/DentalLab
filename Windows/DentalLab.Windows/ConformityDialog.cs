using DentalLab.Core;
using Microsoft.Win32;
using System.IO;
using System.Text.Json.Nodes;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace DentalLab.Windows;

public sealed class ConformityDialog : Window
{
    private JsonObject entry, profile;
    private readonly LocalArchive archive;
    private readonly Dictionary<string,TextBox> inputs=[];
    private readonly CheckBox confirmed=new(){Content="Verifica dei requisiti confermata dal fabbricante"}, implantable=new(){Content="Dispositivo impiantabile"};
    private readonly DatePicker prescriptionDate=new(), releaseDate=new();
    private readonly TextBlock issue=new(){Foreground=Brushes.DarkRed,TextWrapping=TextWrapping.Wrap};
    private readonly bool readOnly;
    private string savedSnapshot;
    private string Snapshot() => entry.ToJsonString()+profile.ToJsonString();
    public ConformityDialog(LocalArchive archive,JsonObject entry,System.Action? newVersion = null)
    {
        this.archive=archive;this.entry=(JsonObject)entry.DeepClone();profile=(JsonObject)(entry["issued"]?["profile"]??archive.Database["profile"]!).DeepClone();readOnly=entry["issued"]!=null||entry["archived"]?.GetValue<bool>()==true;
        this.entry["device"]??=MainWindow.NewDevice(); savedSnapshot=Snapshot();
        Title="Conformità · "+Conformity.Text(entry,"name");Width=Math.Min(960,SystemParameters.WorkArea.Width-40);Height=Math.Min(800,SystemParameters.WorkArea.Height-40);MinWidth=720;MinHeight=500;WindowStartupLocation=WindowStartupLocation.CenterOwner;
        var root=new DockPanel{Margin=new Thickness(24)};Content=root;
        var heading=DesignSystem.Heading("Dichiarazione per dispositivo su misura");DockPanel.SetDock(heading,Dock.Top);root.Children.Add(heading);
        var footer=new StackPanel();DockPanel.SetDock(footer,Dock.Bottom);root.Children.Add(footer);footer.Children.Add(issue);
        var actions=new WrapPanel{Margin=new Thickness(0,14,0,0)};footer.Children.Add(actions);
        void Action(string title,System.Action action,bool primary=false) { var b=new Button{Content=title,Margin=new Thickness(0,0,8,0)};if(primary)b.Style=(Style)FindResource("PrimaryButton");b.Click+=(_,_)=>{try{action();}catch(Exception error){issue.Text=error.Message;}};actions.Children.Add(b); }
        Action("Salva PDF",()=>{Read();var dialog=new SaveFileDialog{Filter="PDF|*.pdf",FileName="DentalLab-Conformita.pdf"};if(dialog.ShowDialog()==true)ConformityOutput.SavePdf(this.entry,PreviewDatabase(),dialog.FileName);},true);
        Action("Stampa",()=>{Read();ConformityOutput.Print(this.entry,PreviewDatabase());});
        if(!readOnly){Action("Salva bozza",()=>{Read();Conformity.Save(archive,this.entry,profile);savedSnapshot=Snapshot();issue.Text="Bozza salvata.";});Action("Registra documento…",()=>{Read();if(NoticeDialog.Show("La registrazione assegna un numero progressivo e blocca il documento. Verifica prima il fascicolo. Non costituisce firma elettronica né certificazione.","Registra dichiarazione",MessageBoxButton.YesNo)!=MessageBoxResult.Yes)return;Conformity.Save(archive,this.entry,profile,true);this.entry=(JsonObject)archive.Database["entries"]!.AsArray().First(e=>Conformity.Text(e,"id")==Conformity.Text(this.entry,"id"))!.DeepClone();DialogResult=true;});}
        if(readOnly && newVersion != null)Action("Nuova versione dal lavoro",()=>{Close();newVersion();});
        Action("Chiudi",()=>Close());
        var form=new StackPanel();root.Children.Add(new ScrollViewer{Content=form,VerticalScrollBarVisibility=ScrollBarVisibility.Auto});
        form.Children.Add(DesignSystem.Caption(readOnly?"Documento registrato/archiviato · sola lettura. I dati del fabbricante sono quelli del documento.":"Bozza collegata al lavoro. Puoi salvarla e stamparla; prima della registrazione completa tutti i campi del fascicolo."));
        void Field(string key,string label,string value,bool multiline=false){form.Children.Add(new TextBlock{Text=label,Margin=new Thickness(0,12,0,6),Foreground=DesignSystem.Brush("Muted")});var box=new TextBox{Text=value,IsReadOnly=readOnly};if(multiline){box.AcceptsReturn=true;box.TextWrapping=TextWrapping.Wrap;box.Height=80;box.VerticalScrollBarVisibility=ScrollBarVisibility.Auto;}inputs.Add(key,box);form.Children.Add(box);}
        Field("name","Titolo / riferimento",Conformity.Text(entry,"name"));Field("patient","Paziente: nome, acronimo o codice",Conformity.Text(entry,"patient"));
        form.Children.Add(DesignSystem.Heading("Fabbricante"));
        foreach(var f in new[]{("name","Ragione sociale"),("productionSites","Luoghi di fabbricazione"),("representative","Mandatario / Non applicabile"),("registration","Registrazione fabbricante")})Field("profile."+f.Item1,f.Item2,Conformity.Text(profile,f.Item1));
        foreach(var f in new[]{("address","Indirizzo"),("zip","CAP"),("city","Comune"),("province","Provincia"),("vat","Partita IVA"),("email","Email"),("phone","Telefono")})Field("contact."+f.Item1,f.Item2,Conformity.Text(profile["contact"],f.Item1));
        form.Children.Add(DesignSystem.Heading("Dispositivo e fascicolo"));
        foreach(var f in new[]{("identifier","Identificativo dispositivo"),("type","Tipologia"),("riskClass","Classe di rischio"),("prescriber","Prescrittore autorizzato"),("institution","Istituzione sanitaria"),("intendedUse","Destinazione d’uso"),("prescription","Caratteristiche specifiche della prescrizione"),("requirements","Requisiti di sicurezza e prestazione"),("exceptions","Eccezioni e motivazioni"),("substances","Sostanze medicinali / tessuti / cellule"),("design","Progettazione"),("manufacturing","Fabbricazione"),("performance","Prestazioni"),("risks","Rischi"),("checks","Controlli"),("instructions","Istruzioni"),("reviewer","Responsabile della verifica")})Field("device."+f.Item1,f.Item2,Conformity.Text(this.entry["device"],f.Item1),!new[]{"identifier","type","riskClass","prescriber","institution","reviewer"}.Contains(f.Item1));
        confirmed.IsChecked=this.entry["device"]!["conformityConfirmed"]?.GetValue<bool>()==true;implantable.IsChecked=this.entry["device"]!["implantable"]?.GetValue<bool>()==true;confirmed.IsEnabled=implantable.IsEnabled=!readOnly;form.Children.Add(confirmed);form.Children.Add(implantable);
        DateTime Date(string key)=>new DateTime(2001,1,1,0,0,0,DateTimeKind.Utc).AddSeconds(this.entry["device"]![key]!.GetValue<double>()).ToLocalTime().Date;
        prescriptionDate.SelectedDate=Date("prescriptionDate");releaseDate.SelectedDate=Date("releaseDate");prescriptionDate.IsEnabled=releaseDate.IsEnabled=!readOnly;
        form.Children.Add(new TextBlock{Text="Data prescrizione",Margin=new Thickness(0,12,0,6)});form.Children.Add(prescriptionDate);form.Children.Add(new TextBlock{Text="Immissione sul mercato dichiarata",Margin=new Thickness(0,12,0,6)});form.Children.Add(releaseDate);
        form.Children.Add(DesignSystem.Heading("Lavorazioni, colori e allegati"));
        form.Children.Add(new TextBlock{Text=string.Join("\n",Conformity.Blocks(this.entry,PreviewDatabase()).Where(b=>b.Title=="Lavorazioni e colori per dente").Select(b=>b.Text))});
        form.Children.Add(new TextBlock{Text=string.Join("\n",this.entry["files"]?.AsArray().Select(f=>Conformity.Text(f,"name"))??[])});
        if(!readOnly){var attach=new Button{Content="Allega prescrizione…",HorizontalAlignment=HorizontalAlignment.Left,Margin=new Thickness(0,12,0,16)};form.Children.Add(attach);attach.Click+=(_,_)=>{try{var dialog=new OpenFileDialog();if(dialog.ShowDialog()!=true)return;if(new FileInfo(dialog.FileName).Length>BackupCodec.FileLimit)throw new InvalidDataException("Limite allegato: 100 MB.");string id=LocalArchive.NewID();archive.SaveBlob(id,File.ReadAllBytes(dialog.FileName));this.entry["files"]??=new JsonArray();this.entry["files"]!.AsArray().Add(new JsonObject{["id"]=id,["name"]=Path.GetFileName(dialog.FileName),["category"]="Prescrizione"});issue.Text="Prescrizione aggiunta. Salva la bozza per conservarla.";}catch(Exception error){issue.Text=error.Message;}};}
        Closing += (_, args) => { if(readOnly || this.entry["issued"]!=null)return; try { Read(); if(Snapshot()!=savedSnapshot && NoticeDialog.Show("Scartare le modifiche non salvate alla dichiarazione?", "Modifiche non salvate",MessageBoxButton.YesNo)!=MessageBoxResult.Yes)args.Cancel=true; } catch(Exception error){args.Cancel=true;issue.Text=error.Message;} };
    }
    private JsonObject PreviewDatabase(){var db=(JsonObject)archive.Database.DeepClone();db["profile"]=profile.DeepClone();return db;}
    private void Read()
    {
        if(readOnly)return;
        foreach(var (key,box) in inputs){var parts=key.Split('.');if(parts.Length==1)entry[key]=box.Text.Trim();else if(parts[0]=="profile")profile[parts[1]]=box.Text.Trim();else if(parts[0]=="contact")profile["contact"]![parts[1]]=box.Text.Trim();else entry["device"]![parts[1]]=box.Text.Trim();}
        entry["device"]!["conformityConfirmed"]=confirmed.IsChecked==true;entry["device"]!["implantable"]=implantable.IsChecked==true;
        foreach(var (key,field) in new[]{("prescriptionDate",prescriptionDate),("releaseDate",releaseDate)}){if(field.SelectedDate==null)throw new InvalidDataException("Scegli le date del documento.");var old=new DateTime(2001,1,1,0,0,0,DateTimeKind.Utc).AddSeconds(entry["device"]![key]!.GetValue<double>()).ToLocalTime().Date;if(old!=field.SelectedDate)entry["device"]![key]=(field.SelectedDate.Value.ToUniversalTime()-new DateTime(2001,1,1,0,0,0,DateTimeKind.Utc)).TotalSeconds;}
    }
}
