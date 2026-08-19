using Microsoft.VisualBasic;

using OpenCvSharp;
using OpenCvSharp.Extensions;
using OpenCvSharp.WpfExtensions;

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Numerics;
using System.Security.Cryptography;
using System.Security.Cryptography.Xml;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Shapes;
using System.Xml.Linq;

using static OpenCvSharp.LineIterator;

using Point = OpenCvSharp.Point;
using Window = System.Windows.Window;

namespace CameraApp;

public partial class ImageViewerWindow : Window
{
    private string filePath;
    //public ObservableCollection<string> ImList { get; set; } = new ObservableCollection<string>();
    public string[] PicName;
    private string[] fs;
    private int controlNum = 0;
    private SetParam setParam = new SetParam();
    private Mat originalMat; // 原始图像
    private int Pheight = 480, Pwidth = 640;
    private double currentScale = 1.0;
    private System.Windows.Point dragStartPoint;
    private bool isDragging = false;
    private int cropW;
    private int cropH;
    private int x;
    private int y;
    private OpenCvSharp.Rect roi;
    private long initTime;
    private Stopwatch stopwatch;

    public ImageViewerWindow()
    {
        InitializeComponent();
        PicImage.Height = Pheight;
        PicImage.Width = Pwidth;
        cropW = Pwidth / 2;
        cropH = Pheight / 2;
        x = (Pwidth - cropW) / 2;
        y = (Pheight - cropH) / 2;
        roi = new OpenCvSharp.Rect(x, y, cropW, cropH);
    }
    public ImageViewerWindow(string filePath)
    {
        InitializeComponent();
        PicImage.Height = Pheight;
        PicImage.Width = Pwidth;
        cropW = Pwidth / 2;
        cropH = Pheight / 2;
        x = (Pwidth - cropW) / 2;
        y = (Pheight - cropH) / 2;
        roi = new OpenCvSharp.Rect(x, y, cropW, cropH);
        DataContext = this;
        this.filePath = filePath;
        fs = Directory.GetFiles(filePath, "D*.");
        Array.Sort(fs);

        string s;
        PicName = new string[fs.Length];
        for (int i = 0; i < fs.Length; i++)
        {
            if (i < 10) s = "   "; else if (i < 100) s = "  "; else s = "";
            PicName[i] = $"{s}{i}  {System.IO.Path.GetFileName(fs[i]).Substring(1)}";
            if (i > 29 && i < 90) PicName[i] += " *";
        }
        ListPic.ItemsSource = PicName;
        ListPic.SelectedIndex = 0;
        stopwatch = Stopwatch.StartNew();
        initTime = stopwatch.ElapsedMilliseconds;
        ViewPic(0);
    }
    public static string ReplaceLast(string input, string oldValue, string newValue)
    {
        int lastIndex = input.LastIndexOf(oldValue);
        if (lastIndex < 0)
            return input; // 未找到，返回原字符串

        return input.Substring(0, lastIndex)
               + newValue
               + input.Substring(lastIndex + oldValue.Length);
    }
    private void ListPic_PreviewMouseDoubleClick(object sender, System.Windows.Input.MouseButtonEventArgs e)
    {
        ViewPic(ListPic.SelectedIndex);
    }

    private void drawEllipse(int x,int y,int r, System.Windows.Media.Brush br)

    {
        controlNum++;

        Ellipse hollowCircle = new Ellipse
        {
            Name = $"Ellipse{controlNum}",
            Width = r,
            Height = r,
            Stroke = br,
            StrokeThickness = 1
        };

        Canvas.SetLeft(hollowCircle, x);
        Canvas.SetTop(hollowCircle, y);
        PicCanvas.Children.Add(hollowCircle);
        Debug.WriteLine($" Control={hollowCircle.Name} Top={dragStartPoint.Y} Left={dragStartPoint.X}");
    }
    private void Img_MouseDown(object sender, MouseButtonEventArgs e)
    {
        dragStartPoint = e.GetPosition(PicImage);
        controlNum++;
        drawEllipse((int)dragStartPoint.X, (int)dragStartPoint.Y, 20, System.Windows.Media.Brushes.Red);
       
    }
    private void Img_MouseRightDown(object sender, MouseButtonEventArgs e)
    {
        var ellipses = PicCanvas.Children.OfType<System.Windows.Shapes.Ellipse>().ToList();
        foreach (var a in ellipses)
        {
            PicCanvas.Children.Remove(a);
        }
    }
    private void Img_MouseUp(object sender, MouseButtonEventArgs e)
    {
        if (dragStartPoint.X < 640) return;
        System.Windows.Point P = e.GetPosition(PicImage);
        Point P2 = new Point(P.X, P.Y);
        Point P1 = new Point(dragStartPoint.X, dragStartPoint.Y);
        if (originalMat != null)
        {
            Mat LingMat = originalMat.Clone();

            Debug.WriteLine($"P1={P1}, P2={P2}");
            Debug.WriteLine($"Image size: {originalMat.Width}x{originalMat.Height}");
            Debug.WriteLine($"Is continuous: {originalMat.IsContinuous()}");

            //var it = new LineIterator(originalMat, P1, P2);
            //Debug.WriteLine($"Count = {it.Count}");
            LingMat.Line(P1, P2, Scalar.Blue, 2);

            var lineIterator = new LineIterator(originalMat, P1, P2);
            //int lineLength = lineIterator.Count;
            var bValues = new List<Point>();
            var gValues = new List<Point>();
            var rValues = new List<Point>();
            int i = 0, j;
            foreach (var point in lineIterator)
            {
                Vec3b vec3b = originalMat.At<Vec3b>(point.Pos.Y, point.Pos.X);
                Vec3b color = vec3b;
                j = i * 2 + 25;
                bValues.Add(new Point(j, 250 - color[0] * 5));
                gValues.Add(new Point(j, 250 - color[1] * 5));
                rValues.Add(new Point(j, 250 - color[2] * 5));
                i++;
            }

            var polygons = new List<List<Point>> { bValues, gValues, rValues };
            Mat histImg = new Mat(250, i * 2 + 50, MatType.CV_8UC3, Scalar.Black);
            Cv2.Polylines(histImg, new[] { bValues }, false, Scalar.Blue, 1);
            Cv2.Polylines(histImg, new[] { gValues }, false, Scalar.Green, 1);
            Cv2.Polylines(histImg, new[] { rValues }, false, Scalar.Red, 1);
            Cv2.ImShow("line", LingMat);
            Cv2.ImShow("Line ColorHistImage", histImg);
            histImg.Dispose(); LingMat.Dispose();
        }
    }

    private void BtnDebugSingle_Click(object sender, RoutedEventArgs e)
    {
        Analysis();
    }

    private void ViewPic(int i)
    {
        if (i < 0 || i >= fs.Length) return;
        if (!(originalMat is null)) originalMat.Dispose();
        //var filestream = new FileStream(fs[i], FileMode.Open);
        //var b = new byte[filestream.Length];
        //filestream.Read(b);
        originalMat = Cv2.ImRead(fs[i], ImreadModes.Color);
        Debug.WriteLine($"roi: left={roi.Left} right={roi.Right} top={roi.Top} bottom={roi.Bottom}");
        originalMat = originalMat.Clone(roi);
        PicImage.Source = originalMat.ToBitmapSource();
        //filestream.Close();

    }
 


    private void BtnAnalyze_Click(object sender, RoutedEventArgs e)
    {
    }

    private void BtnSetPara_Click(object sender, RoutedEventArgs e)
    {

        setParam.ShowDialog();
    }




    private void PicImage_MouseMove(object sender, MouseEventArgs e)
    {
        PicImage.Focus();
        System.Windows.Point p = e.GetPosition(PicImage);
        if (p == dragStartPoint) return;
        if (e.RightButton == MouseButtonState.Pressed)
        {
            x = (int)p.X - cropW / 2;
            y = (int)p.Y - cropH / 2;
            if (x < 0) x = 0;
            if (y < 0) y = 0;
            roi = new OpenCvSharp.Rect(x, y, cropW, cropH);
            ViewPic(ListPic.SelectedIndex);
        }
        else
        {           
            
            dragStartPoint = p;
            ReadPicPoint((int)dragStartPoint.X / 2, (int)dragStartPoint.Y / 2);
        }
    }

    private void ReadPicPoint(int X, int Y)
    {
        if (originalMat != null && X < cropW && Y < cropH)
        {
            Vec3b pixel = originalMat.At<Vec3b>(Y, X);     // 返回 Vec3b 结构
            byte b = pixel.Item0;   // B 通道
            byte g = pixel.Item1;   // G 通道
            byte r = pixel.Item2;   // R 通道
            // 构造一个 1x1 的 BGR Mat
            //Mat bgrPixel = new Mat(1, 1, MatType.CV_8UC3, new Scalar(b, g, r));
            // 转为 HSV
            //Mat hsvPixel = new Mat();
            //Cv2.CvtColor(bgrPixel, hsvPixel, ColorConversionCodes.BGR2HSV);
            // 获取 HSV 值
            //Vec3b hsv = hsvPixel.At<Vec3b>(0, 0);
            LabelInfo.Content = $"Pixel at ({X},{Y}): R={r}, G={g}, B={b} B-R={b - r}";
            //bgrPixel.Dispose();
            //hsvPixel.Dispose();
        }
    }
    private bool AtRange(int R, int G, int B)
    {
        return R >= setParam.MinR && R <= setParam.MaxR
            && G >= setParam.MinG && G <= setParam.MaxG
            && B >= setParam.MinB && B <= setParam.MaxB;
    }

    private void PicImage_KeyUp(object sender, KeyEventArgs e)
    {

        switch (e.Key)
        {
            case Key.Up:
                dragStartPoint.Y--; dragStartPoint.Y--;
                break;
            case Key.Down:
                dragStartPoint.Y++; dragStartPoint.Y++;
                break;
            case Key.Left:
                dragStartPoint.X--; dragStartPoint.X--;
                break;
            case Key.Right:
                dragStartPoint.X++; dragStartPoint.X++;
                break;
        }
        ReadPicPoint((int)dragStartPoint.X, (int)dragStartPoint.Y);
        e.Handled = true;

    }








    private void Analysis()
    {


        var result = DetectPupil(originalMat, out double pupilPx, out double irisPx);

        // 画圈
        if (pupilPx > 0)
        {
            //Cv2.Circle(result, (int)_pupilCenter.X, (int)_pupilCenter.Y, (int)pupilPx, Scalar.Green, 2);
            drawEllipse((int)(int)_pupilCenter.X, (int)_pupilCenter.Y, (int)pupilPx, System.Windows.Media.Brushes.Green);
        }
        if (irisPx > 0)
        {
            //Cv2.Circle(result, (int)_irisCenter.X, (int)_irisCenter.Y, (int)irisPx, Scalar.Red, 2);
            drawEllipse((int)(int)_pupilCenter.X, (int)_pupilCenter.Y, (int)irisPx, System.Windows.Media.Brushes.Red);
        }

        // 计算直径
        double pupilMm = 0;
        string info = "未检测到瞳孔";

        if (irisPx > 0 && pupilPx > 0)
        {
            pupilMm = pupilPx / irisPx * 12f;
            info = $"瞳孔直径 ≈ {pupilMm:F2} mm  (瞳孔{pupilPx:F0}px / 虹膜{irisPx:F0}px × 12 mm)";
        }
        
        LabelInfo.Content = info;
    }

    // ====== 瞳孔检测核心逻辑 ======
    private Point _pupilCenter;
    private Point _irisCenter;

    private Mat DetectPupil(Mat src, out double pupilPx, out double irisPx)
    {
        pupilPx = 0;
        irisPx = 0;
        _pupilCenter = new Point();
        _irisCenter = new Point();

        Cv2.Split(src, out Mat[] ch);
        
        // |B-R| 差值灰度图
        using var diff = new Mat();
        Cv2.Subtract(ch[0], ch[2], diff, dtype: MatType.CV_16S);
        Cv2.Normalize(diff, diff, 0, 255, NormTypes.MinMax); // 拉伸到0~255显示
        diff.ConvertTo(diff, MatType.CV_8U);
        Cv2.ImShow("DiffGray", diff);
       
        // 高斯模糊去噪
        Cv2.GaussianBlur(diff, diff, new OpenCvSharp.Size(5, 5), 0);

        // 查找轮廓
        Cv2.FindContours(diff, out Point[][] contours, out _,
            RetrievalModes.External, ContourApproximationModes.ApproxSimple);

        // 按面积筛选：瞳孔是图像中最大的黑色连通域
        double maxArea = 0;
        Point[] pupilContour = null;

        foreach (var contour in contours)
        {
            var area = Cv2.ContourArea(contour);
            // 根据摄像头分辨率调整，640x480 下瞳孔面积通常在 500~5000
            if (area < 300 || area > 10000) continue;

            // 圆度筛选：瞳孔接近圆形，圆度 = 4π·Area / Perimeter²，越接近1越圆
            var perimeter = Cv2.ArcLength(contour, true);
            if (perimeter == 0) continue;
            var circularity = 4 * Math.PI * area / (perimeter * perimeter);
            if (circularity < 0.2) continue; // 圆度低于0.5的排除

            if (area > maxArea)
            {
                maxArea = area;
                pupilContour = contour;
                Debug.WriteLine($"Found pupil:permeter={perimeter} Area={area}, Circularity={circularity:F2}");
            }
        }

        if (pupilContour != null)
        {
            Cv2.MinEnclosingCircle(pupilContour, out var center, out var radius);
            pupilPx = radius * 2;
            _pupilCenter = new Point(center.X * 2, center.Y * 2);

            // 虹膜估算：虹膜直径约为瞳孔的 2.5~3 倍（取 2.8 倍）
            irisPx = pupilPx * 2.8;
            _irisCenter = _pupilCenter;
        }

        // 在原图上画结果
        var result = src.Clone();
        return result;
    }
}
