using System.Windows;
using FFMpegCore;

namespace CameraApp;

public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
//#if DEBUG
        System.Diagnostics.PresentationTraceSources.DataBindingSource.Switch.Level = System.Diagnostics.SourceLevels.Critical;
//#endif
        // 配置 FFmpeg 路径
        GlobalFFOptions.Configure(options =>
            options.BinaryFolder = @"C:\ProgramData\Microsoft");
    }
}

