using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media.Imaging;

namespace CameraApp;
public class ImageInfo
{
    public string PName { get; set; } = "";
    public string PAge { get; set; } = "";
    public string PSex { get; set; } = "";
    public string FileDir { get; set; } = "";
}

public partial class ImageGalleryWindow : Window
{
    public readonly ObservableCollection<ImageInfo> allImages = new();
    private readonly string capturesFolder = "";

    public ImageGalleryWindow()
    {
        InitializeComponent();
        capturesFolder = Directory.GetCurrentDirectory() + "\\Data";
        if (!Directory.Exists(capturesFolder))
        {
            MessageBox.Show($"没有图像目录: {capturesFolder}", "错误", MessageBoxButton.OK, MessageBoxImage.Error);
            this.Close();
        }

    }

    private void Window_Loaded(object sender, RoutedEventArgs e)
    {
        LoadImages();
    }

    private void LoadImages()
    {
        try
        {
            allImages.Clear();

            var imageDirs = Directory.GetDirectories(capturesFolder);
            string sd;
            FileStream fs;
            byte[] buffer;
            string s;
            string[] lines;
            foreach (var file in imageDirs)
            {
                sd= file + "\\Patient.TXT";
                if (!File.Exists(sd))
                {
                    allImages.Add(new ImageInfo
                    {
                        PName = System.IO.Path.GetFileName(file),
                        PAge = "null",
                        PSex = "null",
                        FileDir = file,
                    });
                }
                else
                {
                    fs = new FileStream(sd, FileMode.Open, FileAccess.Read);
                    buffer = new byte[fs.Length];
                    fs.Read(buffer, 0, buffer.Length);
                    s = System.Text.Encoding.Default.GetString(buffer);
                    lines = s.Split(new string[] { ",", "，" }, StringSplitOptions.None);
                    var fileInfo = new FileInfo(file);

                    if (lines.Length > 4)
                    {

                        allImages.Add(new ImageInfo
                        {
                            PName = lines[0],
                            PAge = lines[1],
                            PSex = lines[2],
                            FileDir = file,
                        });
                    }
                }
            }
            mediaDataGrid.ItemsSource = allImages;
        }
        catch (Exception ex)
        {
            MessageBox.Show($"加载图像失败: {ex.Message}", "错误", MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }


    private void ViewButton_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button button && button.Tag is string filePath)
        {

                var viewerWindow = new ImageViewerWindow(filePath);
                viewerWindow.Owner = this;
                viewerWindow.ShowDialog();
        }
 
    }

    private void DeleteButton_Click(object sender, RoutedEventArgs e)
    {
    
    }


   
}
