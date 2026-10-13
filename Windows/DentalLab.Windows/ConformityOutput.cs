using DentalLab.Core;
using PdfSharp.Drawing;
using PdfSharp.Pdf;
using System.IO;
using System.Text.Json.Nodes;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Media;

namespace DentalLab.Windows;

public static class ConformityOutput
{
    private sealed record Line(int Page, double Top, string Text, bool Heading);
    private static List<Line> Layout(JsonObject entry, JsonObject db)
    {
        using var measure = new PdfDocument(); var page = measure.AddPage(); using var graphics = XGraphics.FromPdfPage(page);
        var body = new XFont("Arial",11,XFontStyleEx.Regular); var heading = new XFont("Arial",12,XFontStyleEx.Bold);
        var lines = new List<Line>(); int number = 0; double y = 134;
        IEnumerable<string> Wrap(string text, XFont font) {
            foreach (string paragraph in text.Replace("\r","").Split('\n')) {
                string line = "";
                foreach (string word in paragraph.Split(' ',StringSplitOptions.RemoveEmptyEntries)) {
                    string trial = line.Length == 0 ? word : line+" "+word;
                    if (graphics.MeasureString(trial,font).Width <= 505) { line = trial; continue; }
                    if (line.Length > 0) { yield return line; line = ""; }
                    foreach (var rune in word.EnumerateRunes()) { string candidate = line+rune; if (line.Length > 0 && graphics.MeasureString(candidate,font).Width > 505) { yield return line; line = rune.ToString(); } else line = candidate; }
                }
                yield return line;
            }
        }
        foreach (var block in Conformity.Blocks(entry,db)) {
            if (y > 710) { number++; y=134; }
            foreach (string text in Wrap(block.Title,heading)) { if (y>748) {number++;y=134;} lines.Add(new(number,y,text,true)); y+=18; }
            y+=4;
            foreach (string text in Wrap(block.Text,body)) { if (y>748) {number++;y=134;} lines.Add(new(number,y,text,false)); y+=16; }
            y+=18;
        }
        return lines;
    }
    private static string Label(JsonObject entry) => Conformity.Text(entry["issued"],"number") is { Length: >0 } value ? value : Conformity.Text(entry,"name");
    private static string State(JsonObject entry) => entry["issued"] == null ? "BOZZA · NON REGISTRATA" : "REGISTRATO";
    public static byte[] Pdf(JsonObject entry, JsonObject db)
    {
        var layout = Layout(entry,db); using var doc = new PdfDocument(); doc.Info.Title="Dichiarazione per dispositivo su misura · "+Label(entry);
        var regular=new XFont("Arial",11,XFontStyleEx.Regular,new XPdfFontOptions(PdfFontEncoding.Unicode)); var bold=new XFont("Arial",12,XFontStyleEx.Bold,new XPdfFontOptions(PdfFontEncoding.Unicode));
        for (int p=0;p<=layout.Max(l=>l.Page);p++) {
            var page=doc.AddPage(); page.Size=PdfSharp.PageSize.A4; using var g=XGraphics.FromPdfPage(page);
            g.DrawString("DENTALLAB",bold,XBrushes.Teal,42,28,XStringFormats.TopLeft);
            g.DrawString("Dichiarazione per dispositivo su misura",new XFont("Arial",20,XFontStyleEx.Bold),XBrushes.DarkSlateGray,42,60,XStringFormats.TopLeft);
            g.DrawString(State(entry),bold,XBrushes.Gray,42,95,XStringFormats.TopLeft);
            foreach (var line in layout.Where(l=>l.Page==p)) g.DrawString(line.Text,line.Heading?bold:regular,line.Heading?XBrushes.Teal:XBrushes.Black,42,line.Top,XStringFormats.TopLeft);
            string label=Label(entry); if(label.Length>65)label=label[..65]; g.DrawString(label,new XFont("Arial",9),XBrushes.Gray,42,797,XStringFormats.TopLeft);
            g.DrawString($"Pagina {p+1}",new XFont("Arial",9),XBrushes.Gray,465,797,XStringFormats.TopLeft);
        }
        using var stream=new MemoryStream(); doc.Save(stream,false); return stream.ToArray();
    }
    public static void SavePdf(JsonObject entry,JsonObject db,string path) => LocalArchive.AtomicWrite(path,Pdf(entry,db));
    public static FixedDocument Printable(JsonObject entry,JsonObject db)
    {
        var layout=Layout(entry,db); var doc=new FixedDocument(); const double scale=96.0/72;
        for(int p=0;p<=layout.Max(l=>l.Page);p++) {
            var page=new FixedPage{Width=595*scale,Height=842*scale,Background=Brushes.White};
            void Text(string text,double x,double y,double size,bool bold=false) { var box=new TextBlock{Text=text,FontFamily=new FontFamily("Arial"),FontSize=size*scale,FontWeight=bold?FontWeights.Bold:FontWeights.Normal,Foreground=Brushes.Black}; FixedPage.SetLeft(box,x*scale);FixedPage.SetTop(box,y*scale);page.Children.Add(box); }
            Text("DENTALLAB",42,28,12,true);Text("Dichiarazione per dispositivo su misura",42,60,20,true);Text(State(entry),42,95,12,true);
            foreach(var line in layout.Where(l=>l.Page==p))Text(line.Text,42,line.Top,line.Heading?12:11,line.Heading);
            string label=Label(entry);Text(label.Length>65?label[..65]:label,42,797,9);Text($"Pagina {p+1}",465,797,9);
            var content=new PageContent();((System.Windows.Markup.IAddChild)content).AddChild(page);doc.Pages.Add(content);
        }
        return doc;
    }
    public static void Print(JsonObject entry,JsonObject db) { var dialog=new PrintDialog();if(dialog.ShowDialog()==true)dialog.PrintDocument(Printable(entry,db).DocumentPaginator,"DentalLab · "+Label(entry)); }
}
