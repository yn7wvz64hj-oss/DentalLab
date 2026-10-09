using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace DentalLab.Windows;

// A single accessible dialog for confirmations, recovery results and errors.
public sealed class NoticeDialog : Window
{
    public NoticeDialog(string title, string message, bool confirm = false)
    {
        Title = title; Width = 540; SizeToContent = SizeToContent.Height;
        MaxHeight = SystemParameters.WorkArea.Height - 80;
        ResizeMode = ResizeMode.NoResize; WindowStartupLocation = WindowStartupLocation.CenterOwner;
        ShowInTaskbar = false;
        var panel = new StackPanel { Margin = new Thickness(28) };
        panel.Children.Add(new TextBlock { Text = confirm ? "CONFERMA OPERAZIONE" : "DENTALLAB · INFORMAZIONI", FontSize = 11, FontWeight = FontWeights.SemiBold, Foreground = DesignSystem.Brush("Accent"), Margin = new Thickness(0,0,0,18) });
        panel.Children.Add(DesignSystem.Heading(title));
        panel.Children.Add(new Border { Background = DesignSystem.Brush("Pale"), CornerRadius = new CornerRadius(12), Padding = new Thickness(18), Child = new ScrollViewer { MaxHeight = 320, VerticalScrollBarVisibility = ScrollBarVisibility.Auto, Content = new TextBlock { Text = message, TextWrapping = TextWrapping.Wrap, LineHeight = 23, Foreground = DesignSystem.Brush("Ink") } } });
        var actions = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, Margin = new Thickness(0,24,0,0) };
        if (confirm) {
            var cancel = new Button { Content = "Annulla", IsCancel = true, IsDefault = true, Margin = new Thickness(0,0,10,0) }; actions.Children.Add(cancel);
        }
        var accept = new Button { Content = confirm ? "Conferma" : "Ho capito", IsDefault = !confirm, IsCancel = !confirm, Style = (Style)FindResource("PrimaryButton") };
        accept.Click += (_,_) => DialogResult = true; actions.Children.Add(accept); panel.Children.Add(actions);
        Content = panel;
    }
    public static MessageBoxResult Show(string message, string title = "DentalLab", MessageBoxButton buttons = MessageBoxButton.OK)
    {
        // Startup errors can occur before resources or the application exist.
        if (Application.Current == null) return MessageBox.Show(message, title, buttons);
        var dialog = new NoticeDialog(title, message, buttons == MessageBoxButton.YesNo);
        if (Application.Current.MainWindow is { IsVisible: true } owner) dialog.Owner = owner;
        bool accepted = dialog.ShowDialog() == true;
        return buttons == MessageBoxButton.YesNo ? (accepted ? MessageBoxResult.Yes : MessageBoxResult.No) : MessageBoxResult.OK;
    }
}
