using DentalLab.Core;
using System.IO;
using Microsoft.Win32;
using System.Security.Cryptography;
using System.Text.Json.Nodes;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Data;
using System.Windows.Media;

namespace DentalLab.Windows;

public static class Program
{
    [STAThread]
    public static void Main(string[] args)
    {
        if (args.Length == 2 && args[0] == "--preview") { PreviewRenderer.Run(args[1]); return; }
        // Global per-machine mutex across Windows sessions; archive also has a file lock.
        using var instance = new Mutex(false, @"Global\DentalLab.LocalArchive"); bool owns = false;
        try {
            try { owns = instance.WaitOne(0); } catch (AbandonedMutexException) { owns = true; }
            if (!owns) { MessageBox.Show("DentalLab è già aperto su questo computer."); return; }
            var folder = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "DentalLab");
            // A separate local folder enables recovery when the original key/archive is damaged.
            if (args.Length == 2 && args[0] == "--archive") folder = Path.GetFullPath(args[1]);
            using var archive = new LocalArchive(folder);
            var app = new Application(); DesignSystem.Install(app); app.Run(new MainWindow(archive));
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
        panel.Children.Add(new TextBlock { Text = "D E N T A L L A B", Foreground = DesignSystem.Brush("Accent"), FontSize = 11, FontWeight = FontWeights.SemiBold, Margin = new Thickness(0,0,0,18) });
        panel.Children.Add(new TextBlock { Text = title, FontSize = 20, FontWeight = FontWeights.SemiBold, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0,0,0,18) }); panel.Children.Add(password);
        if (repeat) { panel.Children.Add(new TextBlock { Text = "Ripeti la password", Margin = new Thickness(0,12,0,4) }); panel.Children.Add(confirmation); }
        var button = new Button { Content = "Continua", Style = (Style)FindResource("PrimaryButton"), Margin = new Thickness(0,20,0,0), Padding = new Thickness(12), IsDefault = true };
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
    private readonly ComboBox section = new(), state = new() { IsEditable = true };
    private readonly ListBox list = new() { MinWidth = 240, DisplayMemberPath = "Label" };
    private readonly TextBox search = new(), name = new(), patient = new(), detail = new() { AcceptsReturn = true, Height = 84, TextWrapping = TextWrapping.Wrap, VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
    private readonly ComboBox client = new() { IsEditable = true, DisplayMemberPath = "Label" };
    private readonly DatePicker date = new();
    private readonly DataGrid teeth = new() { Height = 155, AutoGenerateColumns = false, CanUserAddRows = false, EnableRowVirtualization = false };
    private readonly ListBox attachments = new() { Height = 95, DisplayMemberPath = "Label" };
    private readonly StackPanel editor = new();
    private readonly StackPanel overview = new();
    private readonly ComboBox workFilter = new() { ItemsSource = new[] { "Tutti gli attivi", "Oggi", "In ritardo", "Da iniziare", "In lavorazione", "In prova", "Pronto", "Consegnato", "Archiviati" }, SelectedIndex = 0 };
    private readonly TextBlock resultCount = new();
    private readonly Dictionary<string, Button> navigation = [];
    private Button? saveAction;
    private readonly Dictionary<int,Button> toothButtons = [];
    private readonly TextBlock workspaceTitle = new() { Text = "Lavori", FontSize = 30, FontWeight = FontWeights.SemiBold };
    private JsonObject? current;
    private bool unlocked, dirty, loading;
    private int failed;
    private DateTime retryAfter;
    private List<ToothRow> toothRows = [];
    private const string Classical = "VITA classical A1–D4";
    private static readonly HashSet<string> Shades = ["A1","A2","A3","A3.5","A4","B1","B2","B3","B4","C1","C2","C3","C4","D2","D3","D4"];
    private sealed record Row(string ID, string Label);
    public MainWindow(LocalArchive archive, bool preview = false)
    {
        this.archive = archive; Title = "DentalLab · laboratorio digitale"; Width = 1480; Height = 960; MinWidth = 1280; MinHeight = 760;
        var root = new Grid { Background = DesignSystem.Brush("Canvas") }; Content = root;
        root.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(216) }); root.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(270) }); root.ColumnDefinitions.Add(new ColumnDefinition());
        var sideBorder = new Border { Background = DesignSystem.Brush("Sidebar"), BorderBrush = new SolidColorBrush(Color.FromRgb(43,85,103)), BorderThickness = new Thickness(0,0,1,0), Padding = new Thickness(20,30,20,22) }; root.Children.Add(sideBorder);
        var sidebar = new DockPanel(); sideBorder.Child = sidebar;
        var sideTop = new StackPanel(); DockPanel.SetDock(sideTop,Dock.Top); sidebar.Children.Add(sideTop); sideTop.Children.Add(DesignSystem.Brand());
        sideTop.Children.Add(new TextBlock { Text = "IL TUO ARCHIVIO", Foreground = Brushes.LightSteelBlue, FontSize = 10, FontWeight = FontWeights.SemiBold, Margin = new Thickness(0,0,0,10) });
        var local = new Border { CornerRadius = new CornerRadius(10), BorderBrush = new SolidColorBrush(Color.FromRgb(43,85,103)), BorderThickness = new Thickness(1), Padding = new Thickness(12), Margin = new Thickness(0,18,0,0) };
        local.Child = new TextBlock { Text = "●  ARCHIVIO LOCALE\nCifrato su questo computer", Foreground = Brushes.LightCyan, FontSize = 11, LineHeight = 20 };
        DockPanel.SetDock(local,Dock.Bottom); sidebar.Children.Add(local);
        var dock = new DockPanel { Margin = new Thickness(24,22,24,18) }; Grid.SetColumn(dock,2); root.Children.Add(dock);
        var heading = new DockPanel { Margin = new Thickness(0,0,0,20) }; DockPanel.SetDock(heading,Dock.Top); dock.Children.Add(heading);
        var tag = new Border { Background = DesignSystem.Brush("Pale"), CornerRadius = new CornerRadius(18), Padding = new Thickness(12,7,12,7), VerticalAlignment = VerticalAlignment.Top, Child = new TextBlock { Text = "●  Laboratorio digitale", FontSize = 11, FontWeight = FontWeights.SemiBold, Foreground = DesignSystem.Brush("Accent") } }; DockPanel.SetDock(tag,Dock.Right); heading.Children.Add(tag);
        var titles = new StackPanel(); heading.Children.Add(titles); titles.Children.Add(new TextBlock { Text = "LABORATORIO  /  GESTIONE", FontSize = 10, FontWeight = FontWeights.SemiBold, Foreground = DesignSystem.Brush("Muted"), Margin = new Thickness(0,0,0,6) }); titles.Children.Add(workspaceTitle); titles.Children.Add(new TextBlock { Text = "Ogni dettaglio, in un unico spazio.", FontSize = 13, Foreground = DesignSystem.Brush("Muted"), Margin = new Thickness(0,7,0,0) });
        var toolbar = new WrapPanel { Margin = new Thickness(0,0,0,16) }; DockPanel.SetDock(toolbar, Dock.Top); dock.Children.Add(toolbar);
        Button(toolbar, "Nuovo lavoro", () => { if (Navigate("Lavori")) New(); }); saveAction = Button(toolbar, "Salva scheda", Save); Button(toolbar, "Studi e contatti", () => Navigate("Clienti"));
        var security = Button(toolbar, "Archivio e sicurezza", () => {}); var securityMenu = new ContextMenu(); security.ContextMenu = securityMenu;
        foreach (var action in new (string,Action)[] { ("Esporta backup USB", Export), ("Verifica integrità backup", Verify), ("Ripristina backup", Restore), ("Identità laboratorio", Profile), ("Cambia password", ChangePassword), ("Blocca archivio", Lock) }) { var item = new MenuItem { Header = action.Item1 }; item.Click += (_, _) => Perform(action.Item2); securityMenu.Items.Add(item); }
        security.Click += (_, _) => { securityMenu.PlacementTarget = security; securityMenu.IsOpen = true; };
        var footer = new TextBlock { Text = "Un computer alla volta: esporta e verifica sulla USB, chiudi DentalLab, poi ripristina sull’altro computer.", TextWrapping = TextWrapping.Wrap, Foreground = DesignSystem.Brush("Muted"), FontSize = 11, Margin = new Thickness(0,12,0,0) }; DockPanel.SetDock(footer, Dock.Bottom); dock.Children.Add(footer);
        section.ItemsSource = new[] { "Panoramica", "Lavori", "Scadenze", "Pazienti", "Clienti", "Listino", "Preventivi", "Consegne", "Fatture", "Magazzino", "Conformità", "Qualità", "Sorveglianza" }; section.SelectedItem = preview ? "Lavori" : "Panoramica";
        var nav = new StackPanel(); sidebar.Children.Add(new ScrollViewer { Content = nav, VerticalScrollBarVisibility = ScrollBarVisibility.Auto });
        foreach (var group in new[] { ("OPERATIVITÀ", new[]{"Panoramica","Lavori","Scadenze"}), ("ANAGRAFICHE", new[]{"Clienti","Pazienti","Listino"}), ("AMMINISTRAZIONE", new[]{"Preventivi","Consegne","Fatture","Magazzino"}), ("DOCUMENTAZIONE", new[]{"Conformità","Qualità","Sorveglianza"}) }) {
            nav.Children.Add(new TextBlock { Text = group.Item1, Foreground = Brushes.LightSteelBlue, FontSize = 9, Margin = new Thickness(0,12,0,8) });
            foreach (string module in group.Item2) { var item = Button(nav, module == "Panoramica" ? "Oggi · panoramica" : module == "Clienti" ? "Studi e contatti" : module, () => Navigate(module)); item.HorizontalContentAlignment = HorizontalAlignment.Left; item.Margin = new Thickness(0,0,0,3); item.Background = Brushes.Transparent; item.Foreground = Brushes.White; item.BorderBrush = Brushes.Transparent; navigation[module] = item; }
        }
        var browser = new DockPanel { Margin = new Thickness(14,22,0,18) }; Grid.SetColumn(browser,1); root.Children.Add(browser);
        var find = new StackPanel(); DockPanel.SetDock(find,Dock.Top); browser.Children.Add(find);
        find.Children.Add(DesignSystem.Heading("Archivio")); find.Children.Add(DesignSystem.Caption("Cerca titolo, paziente o studio")); find.Children.Add(search);
        workFilter.Margin = new Thickness(0,10,0,0); find.Children.Add(workFilter); resultCount.Margin = new Thickness(0,12,0,8); resultCount.FontSize = 11; find.Children.Add(resultCount);
        Button(find, "Nuova scheda", New).Margin = new Thickness(0,0,0,12);
        browser.Children.Add(new Border { CornerRadius = new CornerRadius(12), Background = Brushes.White, Padding = new Thickness(4), Child = list });
        var workspace = new Grid(); workspace.Children.Add(editor); workspace.Children.Add(overview);
        dock.Children.Add(new ScrollViewer { Content = workspace, VerticalScrollBarVisibility = ScrollBarVisibility.Auto });
        var info = new StackPanel(); info.Children.Add(DesignSystem.Heading("Informazioni principali"));
        var form = new Grid(); form.ColumnDefinitions.Add(new ColumnDefinition()); form.ColumnDefinitions.Add(new ColumnDefinition()); info.Children.Add(form);
        var left = new StackPanel { Margin = new Thickness(0,0,10,0) }; var right = new StackPanel { Margin = new Thickness(10,0,0,0) }; form.Children.Add(left); Grid.SetColumn(right,1); form.Children.Add(right);
        Field(left, "Titolo / nome", name); Field(right, "Studio · anagrafica Clienti", client); Field(left, "Paziente / codice", patient); Field(right, "Consegna / data", date); Field(left, "Stato", state); Field(info, "Note della lavorazione", detail); editor.Children.Add(DesignSystem.Card(info));
        state.ItemsSource = new[] { "Da iniziare", "In lavorazione", "In prova", "Pronto", "Consegnato", "Aperto", "Chiuso" };
        var dental = new StackPanel(); dental.Children.Add(DesignSystem.Heading("Odontogramma")); dental.Children.Add(DesignSystem.Caption("Denti FDI permanenti e decidui · scegli un elemento e assegna lavorazione e colore."));
        var chart = new StackPanel(); dental.Children.Add(chart);
        foreach (var arch in new[] { new[]{18,17,16,15,14,13,12,11,21,22,23,24,25,26,27,28}, new[]{48,47,46,45,44,43,42,41,31,32,33,34,35,36,37,38}, new[]{55,54,53,52,51,61,62,63,64,65}, new[]{85,84,83,82,81,71,72,73,74,75} }) {
            var row = new UniformGrid { Columns = arch.Length, Margin = new Thickness(0,0,0,4) }; chart.Children.Add(row);
            foreach (int tooth in arch) { var tile = Button(row, tooth.ToString(), () => { if (current == null || ReadOnly()) return; if (toothRows.All(t => t.Dente != tooth)) { toothRows.Add(new ToothRow { Dente = tooth }); RefreshTeeth(); MarkDirty(); } }); tile.Style = (Style)FindResource("ToothButton"); tile.Padding = new Thickness(2,8,2,8); tile.Margin = new Thickness(2); tile.ToolTip = "Dente " + tooth; toothButtons[tooth] = tile; }
        }
        teeth.Margin = new Thickness(0,12,0,8); dental.Children.Add(teeth); Button(dental, "Rimuovi lavorazione del dente selezionato", () => { if (!ReadOnly() && teeth.SelectedItem is ToothRow selected) { toothRows.Remove(selected); RefreshTeeth(); MarkDirty(); } }); editor.Children.Add(DesignSystem.Card(dental));
        foreach (var column in new[] { ("Dente", nameof(ToothRow.Dente)), ("Lavorazione", nameof(ToothRow.Lavorazione)), ("Scala colore", nameof(ToothRow.Scala)), ("Colore", nameof(ToothRow.Colore)) }) teeth.Columns.Add(new DataGridTextColumn { Header = column.Item1, Binding = new Binding(column.Item2), Width = new DataGridLength(column.Item1 is "Dente" or "Colore" ? 0.5 : 1.5, DataGridLengthUnitType.Star) });
        var documents = new StackPanel(); documents.Children.Add(DesignSystem.Heading("Allegati e documenti")); documents.Children.Add(DesignSystem.Caption("Prescrizioni, foto e file del fascicolo, collegati alla scheda.")); documents.Children.Add(attachments);
        var fileButtons = new WrapPanel(); documents.Children.Add(fileButtons); Button(fileButtons, "Aggiungi allegato", Attach); Button(fileButtons, "Esporta allegato", ExportAttachment); Button(fileButtons, "Rimuovi riferimento", RemoveAttachment); editor.Children.Add(DesignSystem.Card(documents));
        var actions = new WrapPanel(); editor.Children.Add(actions); Button(actions, "Salva scheda", Save); Button(actions, "Contatti dello studio", EditContact); Button(actions, "Mostra scheda completa", ShowFullRecord);
        var limitation = new TextBlock { Text = "Documenti registrati e schede archiviate sono in sola lettura. Numerazione fiscale, XML/PDF, magazzino e calendario avanzati si gestiscono sul Mac.", TextWrapping = TextWrapping.Wrap, Foreground = Brushes.DimGray }; editor.Children.Add(limitation);
        section.SelectionChanged += (_, _) => { workspaceTitle.Text = (string)section.SelectedItem == "Panoramica" ? "Il laboratorio, oggi" : (string)section.SelectedItem; if (unlocked) RefreshList(); }; search.TextChanged += (_, _) => { if (!loading && unlocked && CanDiscard()) RefreshList(); };
        workFilter.SelectionChanged += (_, e) => { if (loading || !unlocked) return; if (CanDiscard()) RefreshList(); else { loading = true; if (e.RemovedItems.Count > 0) workFilter.SelectedItem = e.RemovedItems[0]; loading = false; } };
        list.SelectionChanged += (_, _) => { if (!loading && unlocked && list.SelectedItem is Row row) { if (!CanDiscard()) { loading = true; list.SelectedItem = list.Items.Cast<Row>().FirstOrDefault(r => r.ID == current?["id"]?.GetValue<string>()); loading = false; return; } if ((string)section.SelectedItem == "Panoramica") Navigate("Lavori"); Load(row.ID); } };
        foreach (var box in new[] { name, patient, detail }) box.TextChanged += (_, _) => MarkDirty();
        client.SelectionChanged += (_, _) => MarkDirty(); client.AddHandler(TextBox.TextChangedEvent, new TextChangedEventHandler((_, e) => { if (e.OriginalSource is TextBox input && input.IsKeyboardFocusWithin) MarkDirty(); })); state.SelectionChanged += (_, _) => MarkDirty(); state.AddHandler(TextBox.TextChangedEvent, new TextChangedEventHandler((_, e) => { if (e.OriginalSource is TextBox input && input.IsKeyboardFocusWithin) MarkDirty(); })); date.SelectedDateChanged += (_, _) => MarkDirty();
        teeth.CellEditEnding += (_, _) => MarkDirty();
        if (!preview) Closing += (_, e) => { if (!CanDiscard()) e.Cancel = true; };
        if (preview) { unlocked = true; RefreshList(); if (list.Items.Count > 0) { list.SelectedIndex = 0; Load(((Row)list.Items[0]).ID); } }
        else Loaded += (_, _) => { try { if (!Access()) Close(); else { RefreshList(); if (list.Items.Count > 0) list.SelectedIndex = 0; } } catch (Exception e) { MessageBox.Show(e.Message); Close(); } };
    }
    private void MarkDirty() { if (!loading && current != null && !ReadOnly()) dirty = true; }
    private bool CanDiscard() => !dirty || MessageBox.Show("Scartare le modifiche non salvate?", "DentalLab", MessageBoxButton.YesNo) == MessageBoxResult.Yes;
    private static void Field(Panel panel, string label, UIElement field) { panel.Children.Add(new TextBlock { Text = label, FontSize = 12, FontWeight = FontWeights.Medium, Foreground = DesignSystem.Brush("Muted"), Margin = new Thickness(0,9,0,7) }); panel.Children.Add(field); }
    private Button Button(Panel panel, string label, Action action) { var b = new Button { Content = label, Margin = new Thickness(0,0,7,7) }; if (label is "Salva scheda" or "Nuova scheda" or "Nuovo lavoro" or "Continua") b.Style = (Style)FindResource("PrimaryButton"); b.Click += (_, _) => Perform(action); panel.Children.Add(b); return b; }
    private void Perform(Action action) { try { if (!unlocked) { if (!Access()) return; RefreshList(); } action(); } catch (Exception e) { MessageBox.Show(e.Message, "Operazione non completata"); } }
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
        unlocked = false; dirty = false; current = null; list.ItemsSource = null; overview.Children.Clear(); resultCount.Text = "Archivio bloccato"; name.Clear(); patient.Clear(); detail.Clear(); client.Text = ""; state.Text = ""; date.SelectedDate = null; toothRows.Clear(); RefreshTeeth(); attachments.ItemsSource = null; editor.IsEnabled = false;
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
        loading = true;
        string module = (string)section.SelectedItem;
        bool production = module is "Lavori" or "Scadenze" or "Panoramica";
        workFilter.Visibility = production ? Visibility.Visible : Visibility.Collapsed;
        var records = archive.Database["entries"]!.AsArray().OfType<JsonObject>().Where(e => e["section"]!.GetValue<string>() == (production ? "Lavori" : module)).Where(e => ($"{e["name"]} {e["patient"]} {e["client"]}").Contains(search.Text, StringComparison.OrdinalIgnoreCase));
        string filter = (string)workFilter.SelectedItem;
        records = records.Where(e => (e["archived"]?.GetValue<bool>() == true) == (filter == "Archiviati" && production));
        if (production) records = records.Where(e => MatchesWork(e, filter) && (module != "Scadenze" || e["status"]!.GetValue<string>() != "Consegnato"));
        var rows = records.OrderBy(e => production ? Due(e) : DateTime.MaxValue).Select(e => new Row(e["id"]!.GetValue<string>(), production ? $"{e["name"]}\n{e["client"]} · {e["patient"]}\n{Due(e):dd/MM} · {e["status"]}" : $"{e["issued"]?["number"] ?? e["name"]} · {e["patient"]}")).ToList();
        list.ItemsSource = rows; resultCount.Text = $"{rows.Count} schede · ordinate per {(production ? "consegna" : "archivio")}";
        editor.Visibility = module == "Panoramica" ? Visibility.Collapsed : Visibility.Visible; overview.Visibility = module == "Panoramica" ? Visibility.Visible : Visibility.Collapsed;
        foreach (var (key,item) in navigation) { item.Background = key == module ? DesignSystem.Brush("Accent") : Brushes.Transparent; item.BorderBrush = key == module ? DesignSystem.Brush("Cyan") : Brushes.Transparent; }
        BuildOverview();
        current = null; dirty = false; editor.IsEnabled = false; if (saveAction != null) saveAction.IsEnabled = false; loading = false;
        if (module != "Panoramica" && rows.Count > 0) { loading = true; list.SelectedIndex = 0; loading = false; Load(rows[0].ID); }
    }
    private static DateTime Due(JsonObject e) => new DateTime(2001,1,1,0,0,0,DateTimeKind.Utc).AddSeconds(e["date"]!.GetValue<double>()).ToLocalTime().Date;
    private static bool MatchesWork(JsonObject e, string filter) {
        string status = e["status"]!.GetValue<string>();
        return filter switch { "Oggi" => Due(e) == DateTime.Today && status != "Consegnato", "In ritardo" => Due(e) < DateTime.Today && status != "Consegnato", "Tutti gli attivi" or "Archiviati" => true, _ => status == filter };
    }
    private bool Navigate(string module, string filter = "Tutti gli attivi") {
        if (!CanDiscard()) return false; dirty = false; loading = true; search.Clear(); workFilter.SelectedItem = filter; loading = false;
        section.SelectedItem = module; workspaceTitle.Text = module == "Panoramica" ? "Il laboratorio, oggi" : module; RefreshList();
        return true;
    }
    private void BuildOverview() {
        overview.Children.Clear();
        if (!unlocked) return;
        var works = archive.Database["entries"]!.AsArray().OfType<JsonObject>().Where(e => e["section"]!.GetValue<string>() == "Lavori" && e["archived"]?.GetValue<bool>() != true && e["status"]!.GetValue<string>() != "Consegnato").ToList();
        var summary = new UniformGrid { Columns = 3 };
        foreach (var metric in new[] { ("Lavori aperti", works.Count, "Tutti gli attivi"), ("Consegne oggi", works.Count(e => Due(e) == DateTime.Today), "Oggi"), ("In ritardo", works.Count(e => Due(e) < DateTime.Today), "In ritardo") }) { var card = new StackPanel(); card.Children.Add(DesignSystem.Caption(metric.Item1)); card.Children.Add(new TextBlock { Text = metric.Item2.ToString(), FontSize = 32, FontWeight = FontWeights.SemiBold, Foreground = DesignSystem.Brush("Accent") }); Button(card,"Apri elenco",()=>Navigate("Lavori",metric.Item3)); summary.Children.Add(DesignSystem.Card(card)); }
        overview.Children.Add(summary);
        var flow = new StackPanel(); flow.Children.Add(DesignSystem.Heading("Avanzamento produzione")); flow.Children.Add(DesignSystem.Caption("Apri una fase per vedere le commesse e la prossima consegna."));
        var stages = new WrapPanel(); flow.Children.Add(stages);
        foreach (string status in new[] {"Da iniziare","In lavorazione","In prova","Pronto"}) Button(stages,$"{status} · {works.Count(e => e["status"]!.GetValue<string>() == status)}",()=>Navigate("Lavori",status));
        overview.Children.Add(DesignSystem.Card(flow));
        var agenda = new StackPanel(); agenda.Children.Add(DesignSystem.Heading("Prossime consegne"));
        foreach (var e in works.OrderBy(Due).Take(6)) Button(agenda,$"{Due(e):dd/MM}  ·  {e["name"]}\n{e["client"]} · {e["patient"]} · {e["status"]}",()=>{ Navigate("Lavori"); Load(e["id"]!.GetValue<string>()); });
        if (works.Count == 0) agenda.Children.Add(DesignSystem.Caption("Nessuna consegna aperta. Crea un lavoro per organizzare la produzione."));
        Button(agenda,"Nuovo lavoro",()=>{ if (Navigate("Lavori")) New(); }); overview.Children.Add(DesignSystem.Card(agenda));
    }
    // Called only by the isolated synthetic preview fixture; never on a user's archive.
    internal void VerifyWorkflow() {
        void Require(bool condition, string message) { if (!condition) throw new InvalidOperationException("Workspace check: " + message); }
        Navigate("Lavori", "In ritardo"); Require(list.Items.Count == 1 && name.Text == "Corona in zirconia", "overdue excludes delivered and archived cases");
        Navigate("Lavori", "Oggi"); Require(list.Items.Count == 1 && name.Text == "Ponte su tre elementi", "today excludes delivered cases");
        Navigate("Lavori", "Pronto"); Require(list.Items.Count == 1 && name.Text == "Faccette anteriori", "production stage excludes archived cases");
        Navigate("Lavori", "Archiviati"); Require(list.Items.Count == 1 && ReadOnly(), "archive remains read only");
        Navigate("Scadenze"); Require(list.Items.Count == 4, "agenda excludes completed cases");
        Navigate("Clienti"); Require(list.Items.Count == 0 && current == null && !editor.IsEnabled, "empty section cannot edit stale records");
        Navigate("Panoramica"); Require(overview.Visibility == Visibility.Visible && editor.Visibility == Visibility.Collapsed && overview.Children.Count == 3, "overview switches workspace");
        Navigate("Lavori"); Require(list.Items.Count == 5 && current != null, "return to active cases");
        Console.WriteLine("PASS · 8 workspace checks: dates, phases, archive, agenda, selection and overview.");
    }
    internal void ShowOverviewPreview() => Navigate("Panoramica");
    private bool ReadOnly() => current == null || current["issued"] != null || current["archived"]?.GetValue<bool>() == true || current["section"]?.GetValue<string>() is "Fatture" or "Magazzino";
    private void Load(string id) { current = (JsonObject)archive.Database["entries"]!.AsArray().First(e => e!["id"]!.GetValue<string>() == id)!.DeepClone(); LoadForm(); }
    private void LoadForm()
    {
        editor.IsEnabled = true; if (saveAction != null) saveAction.IsEnabled = !ReadOnly();
        loading = true; name.Text = current!["name"]!.GetValue<string>(); patient.Text = current["patient"]!.GetValue<string>(); detail.Text = current["detail"]!.GetValue<string>(); state.Text = current["status"]!.GetValue<string>();
        client.ItemsSource = archive.Database["entries"]!.AsArray().Where(e => e!["section"]!.GetValue<string>() == "Clienti").Select(e => new Row(e!["id"]!.GetValue<string>(), e["name"]!.GetValue<string>())).ToList();
        client.SelectedItem = client.Items.Cast<Row>().FirstOrDefault(r => r.ID == current["clientID"]?.GetValue<string>()); client.Text = current["client"]!.GetValue<string>();
        date.SelectedDate = new DateTime(2001,1,1,0,0,0,DateTimeKind.Utc).AddSeconds(current["date"]!.GetValue<double>()).ToLocalTime().Date;
        toothRows = (current["device"]?["toothWorks"]?.AsArray() ?? new JsonArray()).Select(t => new ToothRow { Dente = t!["tooth"]!.GetValue<int>(), Lavorazione = t["kind"]!.GetValue<string>(), Scala = t["shadeSystem"]!.GetValue<string>(), Colore = t["shade"]!.GetValue<string>() }).ToList();
        RefreshTeeth(); RefreshAttachments(); dirty = false; loading = false;
        foreach (var control in new Control[] { name, patient, detail, client, state, date, teeth }) control.IsEnabled = !ReadOnly();
    }
    private void RefreshTeeth() { teeth.ItemsSource = null; teeth.ItemsSource = toothRows; foreach (var (tooth,tile) in toothButtons) { bool assigned = toothRows.Any(t => t.Dente == tooth); tile.Background = assigned ? DesignSystem.Brush("Pale") : Brushes.White; tile.BorderBrush = assigned ? DesignSystem.Brush("Accent") : DesignSystem.Brush("Line"); } }
    private void RefreshAttachments() => attachments.ItemsSource = (current?["files"]?.AsArray() ?? new JsonArray()).Select(f => new Row(f!["id"]!.GetValue<string>(), f["name"]!.GetValue<string>())).ToList();
    private void New()
    {
        if (!CanDiscard()) return;
        dirty = false;
        if ((string)section.SelectedItem is "Panoramica" or "Scadenze") Navigate("Lavori");
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
        LocalArchive.Audit(next, "Salvataggio Windows", e["id"]!.GetValue<string>()); archive.Save(next); string id = e["id"]!.GetValue<string>(); dirty = false; RefreshList(); list.SelectedItem = list.Items.Cast<Row>().FirstOrDefault(r => r.ID == id); Load(id);
    }
    internal static JsonObject NewDevice()
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
