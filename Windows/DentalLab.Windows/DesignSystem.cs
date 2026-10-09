using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Effects;
using System.Windows.Shapes;

namespace DentalLab.Windows;

public static class DesignSystem
{
    public static void Install(Application app) => app.Resources.MergedDictionaries.Add(new ResourceDictionary { Source = new Uri("/DentalLab;component/Theme.xaml", UriKind.Relative) });
    public static Brush Brush(string key) => (Brush)Application.Current.FindResource(key);
    public static Border Card(UIElement content) => new() {
        Background = Brushes.White, CornerRadius = new CornerRadius(16), BorderBrush = Brush("Line"), BorderThickness = new Thickness(1), Padding = new Thickness(22), Margin = new Thickness(0,0,0,16), Child = content,
        Effect = new DropShadowEffect { Color = Color.FromRgb(12,28,48), Opacity = 0.045, BlurRadius = 18, ShadowDepth = 4 }
    };
    public static TextBlock Heading(string title, string? caption = null) => new() { Text = title, FontSize = 18, FontWeight = FontWeights.SemiBold, Margin = new Thickness(0,0,0,caption == null ? 16 : 8) };
    public static TextBlock Caption(string text) => new() { Text = text, FontSize = 12, Foreground = Brush("Muted"), TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0,0,0,12) };
    public static UIElement Brand()
    {
        var row = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0,0,0,28) };
        var icon = new System.Windows.Shapes.Path { Data = Geometry.Parse("M 22,10 C 12,2 2,6 5,22 C 8,31 8,43 13,40 C 17,38 17,25 22,26 C 27,25 27,38 31,40 C 36,43 36,31 39,22 C 42,6 32,2 22,10 Z"), Fill = new LinearGradientBrush(Color.FromRgb(188,247,255), Color.FromRgb(44,189,214),45), Width = 40, Height = 45, Stretch = Stretch.Uniform, Margin = new Thickness(0,0,12,0) };
        row.Children.Add(icon); var text = new StackPanel(); row.Children.Add(text);
        text.Children.Add(new TextBlock { Text = "DentalLab", FontSize = 26, FontWeight = FontWeights.SemiBold, Foreground = Brushes.White });
        text.Children.Add(new TextBlock { Text = "L A B O R A T O R I O  D I G I T A L E", FontSize = 8, Foreground = Brush("Cyan"), Margin = new Thickness(0,5,0,0) }); return row;
    }
}
