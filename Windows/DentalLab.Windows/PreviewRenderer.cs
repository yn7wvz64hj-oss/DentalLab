using DentalLab.Core;
using System.IO;
using System.Security.Cryptography;
using System.Text.Json.Nodes;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace DentalLab.Windows;

// Renders the real WPF controls with synthetic data, without showing a window.
public static class PreviewRenderer
{
    public static void Run(string output)
    {
        output = Path.GetFullPath(output); Directory.CreateDirectory(Path.GetDirectoryName(output)!);
        string folder = Path.Combine(Path.GetDirectoryName(output)!, "preview-data-" + Guid.NewGuid());
        var app = new Application(); DesignSystem.Install(app);
        try {
            using var archive = new LocalArchive(folder, RandomNumberGenerator.GetBytes(32));
            var db = LocalArchive.NewDatabase(); db["profile"]!["name"] = "Laboratorio Forma";
            foreach (var title in new[] { "Corona in zirconia", "Ponte su tre elementi", "Faccette anteriori", "Bite notturno", "Protesi mobile" }) {
                var work = new JsonObject { ["id"] = LocalArchive.NewID(), ["section"] = "Lavori", ["name"] = title, ["client"] = "Studio Rossi", ["patient"] = "P-2026-042", ["detail"] = "Prescrizione ricevuta. Verificare il colore in prova prima della consegna.", ["status"] = "In lavorazione", ["date"] = LocalArchive.SwiftNow(), ["price"] = 0, ["quantity"] = 0, ["lot"] = "", ["paid"] = false, ["attachments"] = new JsonArray() };
                work["device"] = MainWindow.NewDevice();
                work["device"]!["toothWorks"] = new JsonArray(new JsonObject { ["tooth"] = 11, ["kind"] = "Corona in zirconia", ["shadeSystem"] = "VITA classical A1–D4", ["shade"] = "A2" }, new JsonObject { ["tooth"] = 21, ["kind"] = "Faccetta", ["shadeSystem"] = "VITA 3D-MASTER", ["shade"] = "2M2" });
                db["entries"]!.AsArray().Add(work);
            }
            archive.Save(db);
            var window = new MainWindow(archive, preview: true); var content = (FrameworkElement)window.Content;
            content.Measure(new Size(1440,1160)); content.Arrange(new Rect(0,0,1440,1160)); content.UpdateLayout();
            content.Dispatcher.Invoke(() => {}, System.Windows.Threading.DispatcherPriority.Background);
            content.UpdateLayout();
            var image = new RenderTargetBitmap(1440,1160,96,96,PixelFormats.Pbgra32); image.Render(content);
            var encoder = new PngBitmapEncoder(); encoder.Frames.Add(BitmapFrame.Create(image)); using (var stream = File.Create(output)) encoder.Save(stream);
            window.Close(); Console.WriteLine("Preview rendered: " + output);
        } finally { if (Directory.Exists(folder)) Directory.Delete(folder,true); app.Shutdown(); }
    }
}
