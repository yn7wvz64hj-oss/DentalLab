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
    public static Border Card(UIElement content) {
        var panel = new StackPanel();
        panel.Children.Add(new Rectangle { Height = 3, Width = 76, HorizontalAlignment = HorizontalAlignment.Left, RadiusX = 2, RadiusY = 2, Fill = new LinearGradientBrush(Color.FromRgb(45,211,229), Color.FromRgb(111,107,222),0), Margin = new Thickness(0,0,0,14), IsHitTestVisible = false });
        panel.Children.Add(content);
        return new Border { Background = new LinearGradientBrush(Color.FromArgb(250,255,255,255), Color.FromArgb(245,242,249,255),90), CornerRadius = new CornerRadius(20), BorderBrush = new LinearGradientBrush(Color.FromRgb(147,210,229), Color.FromRgb(208,218,240),45), BorderThickness = new Thickness(1), Padding = new Thickness(22), Margin = new Thickness(0,0,0,18), Child = panel,
            Effect = new DropShadowEffect { Color = Color.FromRgb(39,84,125), Opacity = 0.12, BlurRadius = 24, ShadowDepth = 7 } };
    }
    public static Brush WorkspaceBrush() {
        var group = new DrawingGroup();
        group.Children.Add(new GeometryDrawing(new SolidColorBrush(Color.FromRgb(231,240,250)),null,new RectangleGeometry(new Rect(0,0,56,56))));
        group.Children.Add(new GeometryDrawing(null,new Pen(new SolidColorBrush(Color.FromArgb(30,70,142,171)),0.5),Geometry.Parse("M 0,56 L 0,0 L 56,0")));
        var brush = new DrawingBrush(group) { TileMode = TileMode.Tile, Viewport = new Rect(0,0,56,56), ViewportUnits = BrushMappingMode.Absolute, Stretch = Stretch.None }; brush.Freeze(); return brush;
    }
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
