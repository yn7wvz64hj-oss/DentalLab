using DentalLab.Core;
using System.IO;
using Microsoft.Win32;
using System.Security.Cryptography;
using System.Text.Json.Nodes;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace DentalLab.Windows;

public static class Program
{
    [STAThread]
    public static void Main(string[] args)
    {
        // Global per-machine mutex across Windows sessions; archive also has a file lock.
        using var instance = new Mutex(false, @"Global\DentalLab.LocalArchive"); bool owns = false;
        try {
            try { owns = instance.WaitOne(0); } catch (AbandonedMutexException) { owns = true; }
            if (!owns) { MessageBox.Show("DentalLab è già aperto su questo computer."); return; }
            var folder = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "DentalLab");
            // A separate local folder enables recovery when the original key/archive is damaged.
            if (args.Length == 2 && args[0] == "--archive") folder = Path.GetFullPath(args[1]);
            using var archive = new LocalArchive(folder);
            var app = new Application(); app.Run(new MainWindow(archive));
        } catch (Exception e) { MessageBox.Show("Avvio non riuscito. I dati esistenti sono conservati.\n" + e.Message + "\nPer recuperare usa un backup portabile e una nuova cartella locale: DentalLab.exe --archive C:\\Percorso\\Recupero", "DentalLab"); }
        finally { if (owns) instance.ReleaseMutex(); }
    }
}

public sealed class PasswordDialog : Window
{
    private readonly PasswordBox password = new(), confirmation = new();
    public string Password => password.Password;
    public PasswordDialog(string title, bool repeat = false)
    {
        Title = title; Width = 420; SizeToContent = SizeToContent.Height; WindowStartupLocation = WindowStartupLocation.CenterOwner; ResizeMode = ResizeMode.NoResize;
        var panel = new StackPanel { Margin = new Thickness(24) }; Content = panel;
        panel.Children.Add(new TextBlock { Text = title, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0,0,0,12) }); panel.Children.Add(password);
        if (repeat) { panel.Children.Add(new TextBlock { Text = "Ripeti la password", Margin = new Thickness(0,12,0,4) }); panel.Children.Add(confirmation); }
        var button = new Button { Content = "Continua", Margin = new Thickness(0,16,0,0), Padding = new Thickness(10), IsDefault = true };
        button.Click += (_, _) => { if (repeat && Password != confirmation.Password) { MessageBox.Show("Le password non coincidono."); return; } DialogResult = true; };
        panel.Children.Add(button); Loaded += (_, _) => password.Focus();
    }
}

public sealed class ToothRow
{
    public int Dente { get; set; }
    public string Lavorazione { get; set; } = "Corona in zirconia";
    public string Scala { get; set; } = "VITA classical A1–D4";
    public string Colore { get; set; } = "A2";
}

public sealed class MainWindow : Window
{
    private readonly LocalArchive archive;
    private readonly ComboBox section = new() { Width = 155 }, state = new() { Width = 190, IsEditable = true };
    private readonly ListBox list = new() { MinWidth = 240, DisplayMemberPath = "Label" };
    private readonly TextBox search = new() { Width = 170 }, name = new(), patient = new(), detail = new() { AcceptsReturn = true, Height = 120, TextWrapping = TextWrapping.Wrap, VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
    private readonly ComboBox client = new() { IsEditable = true, DisplayMemberPath = "Label" };
    private readonly DatePicker date = new();
    private readonly DataGrid teeth = new() { Height = 190, AutoGenerateColumns = true, CanUserAddRows = false };
    private readonly ListBox attachments = new() { Height = 95, DisplayMemberPath = "Label" };
    private readonly StackPanel editor = new() { Margin = new Thickness(20) };
    private JsonObject? current;
    private bool unlocked, dirty, loading;
    private int failed;
    private DateTime retryAfter;
    private List<ToothRow> toothRows = [];
    private const string Classical = "VITA classical A1–D4";
    private static readonly HashSet<string> Shades = ["A1","A2","A3","A3.5","A4","B1","B2","B3","B4","C1","C2","C3","C4","D2","D3","D4"];
    private sealed record Row(string ID, string Label);
    public MainWindow(LocalArchive archive)
    {
        this.archive = archive; Title = "DentalLab · archivio locale"; Width = 1150; Height = 880; MinWidth = 950;
        Background = Brushes.White; FontSize = 14;
        var dock = new DockPanel { Margin = new Thickness(14) }; Content = dock;
        var toolbar = new WrapPanel { Margin = new Thickness(0,0,0,12) }; DockPanel.SetDock(toolbar, Dock.Top); dock.Children.Add(toolbar);
        Button(toolbar, "Backup USB", Export); Button(toolbar, "Verifica backup", Verify); Button(toolbar, "Ripristina", Restore); Button(toolbar, "Impostazioni", Profile); Button(toolbar, "Cambia password", ChangePassword); Button(toolbar, "Blocca", Lock);
        var footer = new TextBlock { Text = "Un computer alla volta: esporta e verifica sulla USB, chiudi DentalLab, poi ripristina sull’altro computer.", TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0,12,0,0) }; DockPanel.SetDock(footer, Dock.Bottom); dock.Children.Add(footer);
        var sidebar = new StackPanel { Width = 260 }; DockPanel.SetDock(sidebar, Dock.Left); dock.Children.Add(sidebar);
        section.ItemsSource = new[] { "Lavori", "Pazienti", "Clienti", "Listino", "Preventivi", "Consegne", "Fatture", "Magazzino", "Conformità", "Qualità", "Sorveglianza" }; section.SelectedIndex = 0;
        sidebar.Children.Add(section); sidebar.Children.Add(new TextBlock { Text = "Cerca titolo, paziente o studio", Margin = new Thickness(0,12,0,4) }); sidebar.Children.Add(search);
        Button(sidebar, "Nuova scheda", New); sidebar.Children.Add(list); list.Height = 590;
        dock.Children.Add(new ScrollViewer { Content = editor, VerticalScrollBarVisibility = ScrollBarVisibility.Auto });
        Field(editor, "Titolo / nome", name); Field(editor, "Studio (anagrafica Clienti)", client); Field(editor, "Paziente / codice", patient); Field(editor, "Consegna / data", date); Field(editor, "Stato", state); Field(editor, "Note", detail);
        state.ItemsSource = new[] { "Da iniziare", "In lavorazione", "In prova", "Pronto", "Consegnato", "Aperto", "Chiuso" };
        editor.Children.Add(new TextBlock { Text = "Odontogramma · denti FDI permanenti e decidui", Margin = new Thickness(0,14,0,8) });
        var chart = new WrapPanel(); editor.Children.Add(chart);
        foreach (var arch in new[] { new[]{18,17,16,15,14,13,12,11,21,22,23,24,25,26,27,28}, new[]{48,47,46,45,44,43,42,41,31,32,33,34,35,36,37,38}, new[]{55,54,53,52,51,61,62,63,64,65}, new[]{85,84,83,82,81,71,72,73,74,75} }) {
            var row = new WrapPanel { Width = 700 }; chart.Children.Add(row);
            foreach (int tooth in arch) Button(row, tooth.ToString(), () => { if (current == null || ReadOnly()) return; if (toothRows.All(t => t.Dente != tooth)) { toothRows.Add(new ToothRow { Dente = tooth }); RefreshTeeth(); MarkDirty(); } });
        }
        editor.Children.Add(teeth); Button(editor, "Rimuovi lavorazione del dente selezionato", () => { if (!ReadOnly() && teeth.SelectedItem is ToothRow selected) { toothRows.Remove(selected); RefreshTeeth(); MarkDirty(); } });
        editor.Children.Add(new TextBlock { Text = "Allegati · prescrizioni, documenti, foto", Margin = new Thickness(0,14,0,4) }); editor.Children.Add(attachments);
        var fileButtons = new WrapPanel(); editor.Children.Add(fileButtons); Button(fileButtons, "Aggiungi allegato", Attach); Button(fileButtons, "Esporta allegato", ExportAttachment); Button(fileButtons, "Rimuovi riferimento", RemoveAttachment);
        Button(editor, "Contatti dello studio", EditContact); Button(editor, "Salva scheda", Save); Button(editor, "Mostra scheda completa", ShowFullRecord);
        var limitation = new TextBlock { Text = "Documenti registrati e schede archiviate sono in sola lettura. Numerazione fiscale, XML/PDF, magazzino e calendario avanzati si gestiscono sul Mac.", TextWrapping = TextWrapping.Wrap, Foreground = Brushes.DimGray }; editor.Children.Add(limitation);
        section.SelectionChanged += (_, _) => { if (unlocked && CanDiscard()) RefreshList(); }; search.TextChanged += (_, _) => { if (unlocked && CanDiscard()) RefreshList(); };
        list.SelectionChanged += (_, _) => { if (unlocked && list.SelectedItem is Row row && CanDiscard()) Load(row.ID); };
        foreach (var box in new[] { name, patient, detail }) box.TextChanged += (_, _) => MarkDirty();
        client.SelectionChanged += (_, _) => MarkDirty(); client.AddHandler(TextBox.TextChangedEvent, new TextChangedEventHandler((_, _) => MarkDirty())); state.SelectionChanged += (_, _) => MarkDirty(); state.AddHandler(TextBox.TextChangedEvent, new TextChangedEventHandler((_, _) => MarkDirty())); date.SelectedDateChanged += (_, _) => MarkDirty();
        teeth.CellEditEnding += (_, _) => MarkDirty();
        Closing += (_, e) => { if (!CanDiscard()) e.Cancel = true; };
        Loaded += (_, _) => { try { if (!Access()) Close(); else { RefreshList(); if (list.Items.Count > 0) list.SelectedIndex = 0; } } catch (Exception e) { MessageBox.Show(e.Message); Close(); } };
    }
    private void MarkDirty() { if (!loading && current != null && !ReadOnly()) dirty = true; }
    private bool CanDiscard() => !dirty || MessageBox.Show("Scartare le modifiche non salvate?", "DentalLab", MessageBoxButton.YesNo) == MessageBoxResult.Yes;
    private static void Field(Panel panel, string label, UIElement field) { panel.Children.Add(new TextBlock { Text = label, Margin = new Thickness(0,10,0,4) }); panel.Children.Add(field); }
    private void Button(Panel panel, string label, Action action) { var b = new Button { Content = label, Margin = new Thickness(3), Padding = new Thickness(8,5,8,5) }; b.Click += (_, _) => { try { if (label != "Blocca" && !unlocked) { if (!Access()) return; RefreshList(); } action(); } catch (Exception e) { MessageBox.Show(e.Message, "Operazione non completata"); } }; panel.Children.Add(b); }
    private string? Password(string title, bool repeat = false) { var dialog = new PasswordDialog(title, repeat) { Owner = this }; return dialog.ShowDialog() == true ? dialog.Password : null; }
    private bool Access()
    {
        if (DateTime.UtcNow < retryAfter) { MessageBox.Show("Attendi 30 secondi prima di riprovare."); return false; }
        JsonNode? access = archive.Database["dailyAccess"];
        if (access != null && access["lastDay"]?.GetValue<string>() == DateTime.Now.ToString("yyyy-MM-dd")) { unlocked = true; editor.IsEnabled = true; return true; }
        string? password = Password(access == null ? "Imposta password di accesso (almeno 10 caratteri)" : "Password di accesso", access == null); if (password == null) return false;
        var next = (JsonObject)archive.Database.DeepClone();
        if (access == null) {
            if (password.EnumerateRunes().Count() < 10) { MessageBox.Show("Usa almeno 10 caratteri."); return Access(); }
            byte[] salt = RandomNumberGenerator.GetBytes(16); next["dailyAccess"] = new JsonObject { ["salt"] = Convert.ToBase64String(salt), ["verifier"] = Convert.ToBase64String(BackupCodec.Derive(password, salt)) };
        } else {
            byte[] salt = Convert.FromBase64String(access["salt"]!.GetValue<string>()), verifier = Convert.FromBase64String(access["verifier"]!.GetValue<string>());
            if (salt.Length != 16 || verifier.Length != 32 || !CryptographicOperations.FixedTimeEquals(verifier, BackupCodec.Derive(password, salt))) { if (++failed >= 5) retryAfter = DateTime.UtcNow.AddSeconds(30); MessageBox.Show("Password non corretta."); return Access(); }
        }
        next["dailyAccess"]!["lastDay"] = DateTime.Now.ToString("yyyy-MM-dd"); LocalArchive.Audit(next, "Accesso Windows"); archive.Save(next); unlocked = true; failed = 0; editor.IsEnabled = true; return true;
    }
    private void Lock()
    {
        if (!unlocked || !CanDiscard()) return;
        var next = (JsonObject)archive.Database.DeepClone(); next["dailyAccess"]!["lastDay"] = null; archive.Save(next);
        unlocked = false; dirty = false; current = null; list.ItemsSource = null; name.Clear(); patient.Clear(); detail.Clear(); client.Text = ""; state.Text = ""; date.SelectedDate = null; toothRows.Clear(); RefreshTeeth(); attachments.ItemsSource = null; editor.IsEnabled = false;
    }
    private void ChangePassword()
    {
        var old = Password("Password attuale"); if (old == null) return; var access = archive.Database["dailyAccess"]!;
        if (!CryptographicOperations.FixedTimeEquals(Convert.FromBase64String(access["verifier"]!.GetValue<string>()), BackupCodec.Derive(old, Convert.FromBase64String(access["salt"]!.GetValue<string>())))) throw new InvalidDataException("Password non corretta.");
        var password = Password("Nuova password di accesso (almeno 10 caratteri)", true); if (password == null) return;
        if (password.EnumerateRunes().Count() < 10) throw new InvalidDataException("Usa almeno 10 caratteri.");
        var next = (JsonObject)archive.Database.DeepClone(); byte[] salt = RandomNumberGenerator.GetBytes(16); next["dailyAccess"] = new JsonObject { ["salt"] = Convert.ToBase64String(salt), ["verifier"] = Convert.ToBase64String(BackupCodec.Derive(password, salt)), ["lastDay"] = DateTime.Now.ToString("yyyy-MM-dd") }; LocalArchive.Audit(next, "Password aggiornata Windows"); archive.Save(next);
    }
    private void RefreshList()
    {
        loading = true; list.ItemsSource = archive.Database["entries"]!.AsArray().Where(e => e!["section"]!.GetValue<string>() == (string)section.SelectedItem && ($"{e["name"]} {e["patient"]} {e["client"]}").Contains(search.Text, StringComparison.OrdinalIgnoreCase)).Select(e => new Row(e!["id"]!.GetValue<string>(), $"{e["issued"]?["number"] ?? e["name"]} · {e["patient"]}")).ToList();
        current = null; dirty = false; loading = false;
    }
    private bool ReadOnly() => current == null || current["issued"] != null || current["archived"]?.GetValue<bool>() == true || current["section"]?.GetValue<string>() is "Fatture" or "Magazzino";
    private void Load(string id) { current = (JsonObject)archive.Database["entries"]!.AsArray().First(e => e!["id"]!.GetValue<string>() == id)!.DeepClone(); LoadForm(); }
    private void LoadForm()
    {
        loading = true; name.Text = current!["name"]!.GetValue<string>(); patient.Text = current["patient"]!.GetValue<string>(); detail.Text = current["detail"]!.GetValue<string>(); state.Text = current["status"]!.GetValue<string>();
        client.ItemsSource = archive.Database["entries"]!.AsArray().Where(e => e!["section"]!.GetValue<string>() == "Clienti").Select(e => new Row(e!["id"]!.GetValue<string>(), e["name"]!.GetValue<string>())).ToList();
        client.SelectedItem = client.Items.Cast<Row>().FirstOrDefault(r => r.ID == current["clientID"]?.GetValue<string>()); client.Text = current["client"]!.GetValue<string>();
        date.SelectedDate = new DateTime(2001,1,1,0,0,0,DateTimeKind.Utc).AddSeconds(current["date"]!.GetValue<double>()).ToLocalTime().Date;
        toothRows = (current["device"]?["toothWorks"]?.AsArray() ?? new JsonArray()).Select(t => new ToothRow { Dente = t!["tooth"]!.GetValue<int>(), Lavorazione = t["kind"]!.GetValue<string>(), Scala = t["shadeSystem"]!.GetValue<string>(), Colore = t["shade"]!.GetValue<string>() }).ToList();
        RefreshTeeth(); RefreshAttachments(); dirty = false; loading = false;
        foreach (var control in new Control[] { name, patient, detail, client, state, date, teeth }) control.IsEnabled = !ReadOnly();
    }
    private void RefreshTeeth() { teeth.ItemsSource = null; teeth.ItemsSource = toothRows; }
    private void RefreshAttachments() => attachments.ItemsSource = (current?["files"]?.AsArray() ?? new JsonArray()).Select(f => new Row(f!["id"]!.GetValue<string>(), f["name"]!.GetValue<string>())).ToList();
    private void New()
    {
        if (!CanDiscard()) return;
        if ((string)section.SelectedItem is "Fatture" or "Magazzino") throw new InvalidDataException("Crea fatture e materiali dal Mac.");
        current = new JsonObject { ["id"] = LocalArchive.NewID(), ["section"] = (string)section.SelectedItem, ["name"] = "", ["client"] = "", ["patient"] = "", ["detail"] = "", ["status"] = "Da iniziare", ["date"] = LocalArchive.SwiftNow(), ["price"] = 0, ["quantity"] = 0, ["lot"] = "", ["paid"] = false, ["attachments"] = new JsonArray(), ["created"] = LocalArchive.SwiftNow() };
        LoadForm(); dirty = true;
    }
    private void Save()
    {
        if (ReadOnly()) throw new InvalidDataException("Scheda in sola lettura.");
        teeth.CommitEdit(DataGridEditingUnit.Cell, true); teeth.CommitEdit(DataGridEditingUnit.Row, true);
        if (string.IsNullOrWhiteSpace(name.Text)) throw new InvalidDataException("Inserisci un titolo o nome.");
        var valid = Enumerable.Range(1,8).SelectMany(q => Enumerable.Range(1, q <= 4 ? 8 : 5).Select(t => q * 10 + t)).ToHashSet();
        if (toothRows.Select(t => t.Dente).Distinct().Count() != toothRows.Count || toothRows.Any(t => !valid.Contains(t.Dente) || string.IsNullOrWhiteSpace(t.Lavorazione) || string.IsNullOrWhiteSpace(t.Scala) || string.IsNullOrWhiteSpace(t.Colore) || (t.Scala == Classical && !Shades.Contains(t.Colore)))) throw new InvalidDataException("Controlla denti FDI, lavorazioni e colori.");
        var e = (JsonObject)current!.DeepClone(); e["name"] = name.Text.Trim(); e["patient"] = patient.Text; e["detail"] = detail.Text; e["status"] = state.Text;
        var linked = client.Items.Cast<Row>().FirstOrDefault(r => r.Label == client.Text); e["client"] = client.Text; e["clientID"] = linked?.ID;
        if (date.SelectedDate == null) throw new InvalidDataException("Scegli una data.");
        // Keep the exact imported date if the visible local day has not changed.
        var oldDate = new DateTime(2001,1,1,0,0,0,DateTimeKind.Utc).AddSeconds(e["date"]!.GetValue<double>()).ToLocalTime().Date;
        if (date.SelectedDate != oldDate) e["date"] = (date.SelectedDate.Value.ToUniversalTime() - new DateTime(2001,1,1,0,0,0,DateTimeKind.Utc)).TotalSeconds;
        e["updated"] = LocalArchive.SwiftNow();
        if (toothRows.Count > 0 || e["device"]?["toothWorks"] != null) {
            e["device"] ??= NewDevice();
            e["device"]!["toothWorks"] = new JsonArray(toothRows.OrderBy(t => t.Dente).Select(t => (JsonNode)new JsonObject { ["tooth"] = t.Dente, ["kind"] = t.Lavorazione, ["shadeSystem"] = t.Scala, ["shade"] = t.Colore }).ToArray());
        }
        var next = (JsonObject)archive.Database.DeepClone(); var entries = next["entries"]!.AsArray(); int index = entries.Select((node,i) => (node,i)).Where(p => p.node!["id"]!.GetValue<string>() == e["id"]!.GetValue<string>()).Select(p => p.i).DefaultIfEmpty(-1).First();
        if (index < 0) entries.Add(e); else entries[index] = e;
        LocalArchive.Audit(next, "Salvataggio Windows", e["id"]!.GetValue<string>()); archive.Save(next); string id = e["id"]!.GetValue<string>(); dirty = false; RefreshList(); Load(id);
    }
    private static JsonObject NewDevice()
    {
        var d = new JsonObject();
        foreach (string key in new[]{"identifier","prescriber","institution","prescription","teeth","shade","intendedUse","design","manufacturing","performance","risks","requirements","exceptions","instructions","checks","reviewer"}) d[key] = "";
        d["identifier"] = "DL-" + LocalArchive.NewID()[..8]; d["type"] = "Protesi fissa"; d["riskClass"] = "Da valutare"; d["substances"] = "Da valutare"; d["implantable"] = false; d["conformityConfirmed"] = false; d["prescriptionDate"] = LocalArchive.SwiftNow(); d["releaseDate"] = LocalArchive.SwiftNow(); return d;
    }
    private void Attach()
    {
        if (ReadOnly()) throw new InvalidDataException("Scheda in sola lettura."); var dialog = new OpenFileDialog(); if (dialog.ShowDialog() != true) return;
        if (new FileInfo(dialog.FileName).Length > BackupCodec.FileLimit) throw new InvalidDataException("Limite allegato: 100 MB.");
        string id = LocalArchive.NewID(); archive.SaveBlob(id, File.ReadAllBytes(dialog.FileName)); current!["files"] ??= new JsonArray(); current["files"]!.AsArray().Add(new JsonObject { ["id"] = id, ["name"] = Path.GetFileName(dialog.FileName), ["category"] = "Generale" }); dirty = true; RefreshAttachments();
    }
    private void RemoveAttachment() { if (ReadOnly()) throw new InvalidDataException("Scheda in sola lettura."); if (attachments.SelectedItem is Row row) { var files = current!["files"]!.AsArray(); files.Remove(files.First(f => f!["id"]!.GetValue<string>() == row.ID)); dirty = true; RefreshAttachments(); } }
    private void ExportAttachment() { if (attachments.SelectedItem is not Row row) return; var dialog = new SaveFileDialog { FileName = Path.GetFileName(row.Label) }; if (dialog.ShowDialog() == true) { LocalArchive.AtomicWrite(dialog.FileName, archive.Blob(row.ID)); MessageBox.Show("Allegato esportato in chiaro."); } }
    private void Export()
    {
        if (dirty) throw new InvalidDataException("Salva o scarta le modifiche prima del backup.");
        string? password = Password("Password backup (almeno 12 caratteri)", true); if (password == null) return;
        var dialog = new SaveFileDialog { Filter = "Backup DentalLab|*.dlbackup", FileName = $"DentalLab-{DateTime.Now:yyyy-MM-dd}.dlbackup" }; if (dialog.ShowDialog() == true) { archive.Export(dialog.FileName, password); MessageBox.Show("Backup cifrato esportato e verificato. Chiudi DentalLab prima di passare all’altro computer."); }
    }
    private string? BackupPath() { var dialog = new OpenFileDialog { Filter = "Backup DentalLab|*.dlbackup" }; return dialog.ShowDialog() == true ? dialog.FileName : null; }
    private void Verify() { string? path = BackupPath(); if (path == null) return; string? password = Password("Password del backup"); if (password == null) return; var payload = archive.VerifyBackup(path, password); MessageBox.Show($"Backup verificato: {payload["database"]!["entries"]!.AsArray().Count} schede, {payload["files"]!.AsObject().Count} allegati."); }
    private void Restore()
    {
        if (!CanDiscard()) return; string? path = BackupPath(); if (path == null) return; string? password = Password("Password del backup"); if (password == null) return;
        var payload = archive.VerifyBackup(path, password);
        if (MessageBox.Show($"Backup verificato: {payload["database"]!["entries"]!.AsArray().Count} schede. Sostituire l’archivio? Prima verrà salvata una copia completa locale. Il ripristino sostituisce le schede, senza unire gli archivi.", "Ripristino", MessageBoxButton.YesNo) != MessageBoxResult.Yes) return;
        string rescue = archive.Restore(path, password); dirty = false; RefreshList(); MessageBox.Show("Ripristino completato. Copia preventiva:\n" + rescue);
    }
    private void Profile()
    {
        var window = new Window { Title = "Identità laboratorio", Owner = this, Width = 480, SizeToContent = SizeToContent.Height, WindowStartupLocation = WindowStartupLocation.CenterOwner };
        var panel = new StackPanel { Margin = new Thickness(20) }; window.Content = panel; var profile = (JsonObject)archive.Database["profile"]!.DeepClone(); var lab = new TextBox { Text = profile["name"]!.GetValue<string>() }; Field(panel, "Ragione sociale", lab);
        var fields = new Dictionary<string,TextBox>(); foreach (var key in new[] { "address", "zip", "city", "province", "email", "phone", "vat" }) { var field = new TextBox { Text = profile["contact"]![key]!.GetValue<string>() }; fields.Add(key, field); Field(panel, key, field); }
        Button(panel, "Salva", () => { profile["name"] = lab.Text; foreach (var (key,field) in fields) profile["contact"]![key] = field.Text; var next = (JsonObject)archive.Database.DeepClone(); next["profile"] = profile; LocalArchive.Audit(next, "Impostazioni Windows"); archive.Save(next); window.Close(); }); window.ShowDialog();
    }
    private void EditContact()
    {
        if (ReadOnly() || current?["section"]?.GetValue<string>() != "Clienti") throw new InvalidDataException("Seleziona una scheda studio modificabile in Clienti.");
        var contact = (JsonObject)(current["contact"] ?? LocalArchive.NewDatabase()["profile"]!["contact"]!).DeepClone();
        var window = new Window { Title = "Contatti e dati dello studio", Owner = this, Width = 460, Height = 720, WindowStartupLocation = WindowStartupLocation.CenterOwner };
        var panel = new StackPanel { Margin = new Thickness(20) }; window.Content = new ScrollViewer { Content = panel, VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
        var fields = new Dictionary<string,TextBox>(); var labels = new Dictionary<string,string> { ["vat"]="Partita IVA", ["taxCode"]="Codice fiscale", ["address"]="Indirizzo", ["zip"]="CAP", ["city"]="Città", ["province"]="Provincia", ["email"]="Email", ["phone"]="Telefono", ["recipient"]="Codice destinatario", ["pec"]="PEC" };
        foreach (var (key,label) in labels) { var box = new TextBox { Text = contact[key]?.GetValue<string>() ?? "" }; fields[key] = box; Field(panel, label, box); }
        Button(panel, "Applica alla scheda", () => { foreach (var (key,box) in fields) contact[key] = box.Text; current["contact"] = contact; dirty = true; window.Close(); }); window.ShowDialog();
    }
    private void ShowFullRecord()
    {
        if (current == null) return;
        var labels = new Dictionary<string,string> { ["name"]="Nome", ["patient"]="Paziente", ["client"]="Studio", ["device"]="Dispositivo", ["toothWorks"]="Odontogramma", ["tooth"]="Dente", ["kind"]="Lavorazione", ["shadeSystem"]="Scala colore", ["shade"]="Colore", ["detail"]="Note", ["section"]="Sezione", ["status"]="Stato", ["files"]="Allegati", ["contact"]="Contatti", ["issued"]="Documento registrato", ["number"]="Numero", ["lines"]="Righe documento", ["title"]="Descrizione", ["unitPrice"]="Prezzo unitario", ["quantity"]="Quantità", ["vat"]="IVA", ["prescriber"]="Prescrittore", ["prescription"]="Prescrizione", ["identifier"]="Identificativo dispositivo" };
        var text = new System.Text.StringBuilder();
        void Render(JsonNode? node, int depth) {
            if (node is JsonObject obj) foreach (var (key,value) in obj) {
                if (value == null || key is "id" or "digest" or "attachments" || key.EndsWith("ID")) continue;
                text.Append(' ',depth*2).Append(labels.GetValueOrDefault(key,key)).Append(": ");
                if (value is JsonValue) text.AppendLine(value.ToString()); else { text.AppendLine(); Render(value,depth+1); }
            } else if (node is JsonArray array) foreach (var value in array) { text.Append(' ',depth*2).AppendLine("•"); Render(value,depth+1); }
        }
        Render(current,0);
        var window = new Window { Title = "Scheda completa · sola lettura", Owner = this, Width = 780, Height = 650, Content = new TextBox { Text = text.ToString(), IsReadOnly = true, AcceptsReturn = true, VerticalScrollBarVisibility = ScrollBarVisibility.Auto, TextWrapping = TextWrapping.Wrap } }; window.ShowDialog();
    }
}
