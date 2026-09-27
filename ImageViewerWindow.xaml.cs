using OpenCvSharp;
using OpenCvSharp.WpfExtensions;

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection.Metadata;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Forms;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Shapes;

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

    private void drawEllipse(int x, int y, int r, System.Windows.Media.Brush br)

    {
        controlNum++;

        Ellipse hollowCircle = new Ellipse
        {
            Name = $"Ellipse{controlNum}",
            Width = r,
            Height = r,
            Stroke = br,
            StrokeThickness = 2
        };
        int r1 = r / 2 - 10;
        Canvas.SetLeft(hollowCircle, x - r1);
        Canvas.SetTop(hollowCircle, y - r1);
        CanvasOverlay.Children.Add(hollowCircle);

        Debug.WriteLine($" EllipseControl={hollowCircle.Name} X={x}/{dragStartPoint.X:f2} Y={y}/{dragStartPoint.Y:f2} r={r} ");
    }
    private void Img_MouseDown(object sender, MouseButtonEventArgs e)
    {
        dragStartPoint = e.GetPosition(PicImage);
        drawEllipse((int)dragStartPoint.X, (int)dragStartPoint.Y, 60, System.Windows.Media.Brushes.Red);

    }
    private void Img_MouseRightDown(object sender, MouseButtonEventArgs e)
    {
        var ellipses = CanvasOverlay.Children.OfType<System.Windows.Shapes.Ellipse>().ToList();
        string s = "";
        foreach (var a in ellipses)
        {
            CanvasOverlay.Children.Remove(a);
            s += a.Name + ",";
        }
        Debug.WriteLine($"Removed ellipses: {s}  Count={ellipses.Count}");
        controlNum = 0;
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
        originalMat = Cv2.ImRead(fs[i], ImreadModes.Color);
        //Debug.WriteLine($"roi: left={roi.Left} right={roi.Right} top={roi.Top} bottom={roi.Bottom}");
        originalMat = originalMat.Clone(roi);
        PicImage.Source = originalMat.ToBitmapSource();
    }
    
    private void BtnAnalyze_Click(object sender, RoutedEventArgs e)
    {
        Pen redPen = new Pen(Brushes.Red, 2);
        Pen bluePen = new Pen(Brushes.Blue, 2);
        CanvasOverlay.Children.Clear();
        DrawingVisual visual = new DrawingVisual();
        using (DrawingContext dc = visual.RenderOpen())
        {
            dc.DrawLine(bluePen, new System.Windows.Point(20, 20), new System.Windows.Point(20, 400));
            dc.DrawLine(bluePen, new System.Windows.Point(20, 400), new System.Windows.Point(600, 400));
            System.Windows.Point p1 = new System.Windows.Point(20, 400);
            System.Windows.Point p2 = new System.Windows.Point(300, 300);
            int x0 = 20;
            int pipul = 0;
            int k0 = int.Parse(System.IO.Path.GetFileName(fs[30]).Substring(1));
            for (int i = 30; i < 90; i++)
            {
                Debug.WriteLine($"Analyzing image: {PicName[i]}");
                ViewPic(i);
                pipul = DetectPupil(originalMat);
                int k = int.Parse(System.IO.Path.GetFileName(fs[i]).Substring(1));
                Debug.WriteLine($"Extracted value k={k} from filename {fs[i]}");
                p2 = new System.Windows.Point((k - k0)/10, 400 - pipul * 4);
                x0+= 5;
                dc.DrawLine(redPen, p1, p2);
                p1 = p2;
            }
        }
        // 将 DrawingVisual 添加到 Canvas
        CanvasOverlay.Children.Add(new VisualHost { Visual = visual });
    }
    public class VisualHost : FrameworkElement
    {
        public DrawingVisual Visual { get; set; }

        public VisualHost()
        {
            AddVisualChild(Visual);
            AddLogicalChild(Visual);
        }

        protected override Visual GetVisualChild(int index) => Visual;
        protected override int VisualChildrenCount => 1;
    }
    private void BtnSetPara_Click(object sender, RoutedEventArgs e)
    {
        if(setParam == null) setParam = new SetParam();
        setParam.Visibility= Visibility.Visible;
    }

    private void PicImage_MouseMove(object sender, System.Windows.Input.MouseEventArgs e)
    {
        PicImage.Focus();
        System.Windows.Point p = e.GetPosition(PicImage);
        if (p == dragStartPoint) return;
        if (e.RightButton == MouseButtonState.Pressed)
        {
            int dx= (int)(p.X - dragStartPoint.X);
            int dy= (int)(p.Y - dragStartPoint.Y);
            if (Math.Abs(dx) > 10 || Math.Abs(dy) > 10)
            {
                roi.X -= dx;
                roi.Y -= dy;
                if (roi.X < 0) roi.X = 0;
                if (roi.Y < 0) roi.Y = 0;
                if (roi.X + cropW > Pwidth) roi.X = Pwidth - cropW;
                if (roi.Y + cropH > Pheight) roi.Y = Pheight - cropH;
                ViewPic(ListPic.SelectedIndex);
                dragStartPoint = p;
            }
        }
        else
        {

            dragStartPoint = p;
            ReadPicPoint((int)dragStartPoint.X / 2, (int)dragStartPoint.Y / 2);
        }
    }

    private void ReadPicPoint(int X, int Y)
    {
        if (originalMat.IsDisposed) return;
        if (originalMat.Empty()|| originalMat == null) return;
        if (X < cropW && Y < cropH)
        {
            if(originalMat.Channels() == 1)
            {
                LabelInfo.Content = $"Pixel at ({X},{Y}): Not a 3-channel image.";
                return;
            }
            Vec3b pixel = originalMat.At<Vec3b>(Y, X);     // 返回 Vec3b 结构
            byte b = pixel.Item0;   // B 通道
            byte g = pixel.Item1;   // G 通道
            byte r = pixel.Item2;   // R 通道
            LabelInfo.Content = $"Pixel at ({X},{Y}): R={r}, G={g}, B={b} B-R={b - r}";

            // 假设 myImage 是界面上的 Image 控件
            BitmapSource bitmapSource = PicImage.Source as BitmapSource;
            if (bitmapSource == null) return;
            int bytesPerPixel = (bitmapSource.Format.BitsPerPixel + 7) / 8;
            byte[] pixelData = new byte[bytesPerPixel];
            // 计算跨距（每行像素的字节数）
            int stride = bitmapSource.PixelWidth * bytesPerPixel;

            // 拷贝 (x, y) 处 1x1 区域的像素数据
            bitmapSource.CopyPixels(new Int32Rect(X, Y, 1, 1), pixelData, stride, 0);
            if (pixelData.Length == 3)
            {
                byte b2 = pixelData[0];
                byte g2 = pixelData[1];
                byte r2 = pixelData[2];
                LabelInfo.Content += $" || BitmapSource Pixel: R={r2}, G={g2}, B={b2}";
            }
            else if (pixelData.Length == 1)
            {
                byte gray = pixelData[0];
                LabelInfo.Content += $" || BitmapSource Pixel: Gray={gray}";
            }
            else
            {
                LabelInfo.Content += $" || data={pixelData} l={pixelData.Length}";
            }
        }
    }

    private void PicImage_KeyUp(object sender, System.Windows.Input.KeyEventArgs e)
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
        DetectPupil(originalMat);
    }

    // ====== 瞳孔检测核心逻辑 ======
    private Point _pupilCenter;
    private Point _irisCenter;
    private bool selected = true;
    private int DetectPupil(Mat src)
    {
        double pupilPx = 0;
        double irisPx = 0;
        _pupilCenter = new Point();
        _irisCenter = new Point();

        Cv2.Split(originalMat, out Mat[] ch);

        // |B-R| 差值灰度图
        using var diff = new Mat();
        Cv2.Subtract(ch[0], ch[2], diff, dtype: MatType.CV_16S);
        Cv2.Normalize(diff, diff, 0, 255, NormTypes.MinMax); // 拉伸到0~255显示
        diff.ConvertTo(diff, MatType.CV_8U);
        //Cv2.ImShow("DiffGray", diff);

        if (selected)
        {
            Cv2.GaussianBlur(diff, diff, new OpenCvSharp.Size(9, 9), 2);
            //Debug.WriteLine($"霍夫圆检测参数：dp={setParam.Dp}, minDist={setParam.MinDist}, param1={setParam.Param1}, param2={setParam.Param2}, minRadius={setParam.MinRadius}, maxRadius={setParam.MaxRadius}");
            // 2. 霍夫圆检测
            CircleSegment[] circles = Cv2.HoughCircles(
                diff,
                HoughModes.GradientAlt,   // 梯度法（最常用）
                dp: setParam.Dp,                 // 累加器分辨率，1=原图分辨率
                minDist: setParam.MinDist,           // 圆心最小间距
                param1: setParam.Param1,           // Canny 高阈值（低阈值自动=50）
                param2: setParam.Param2,            // 累加器阈值，越小越敏感
                minRadius: setParam.MinRadius,         // 最小半径
                maxRadius: setParam.MaxRadius         // 最大半径
            );
            if (circles.Length == 0) { LabelInfo.Content = "未检测到圆形瞳孔"; return 0; }
            // 3. 绘制结果
            //originalMat = diff;
            PicImage.Source = diff.ToBitmapSource();
            string info = "霍夫圆检测到：";
            int count = 500;
            foreach (var c in circles)
            {
                if(c.Radius < count) count = (int)c.Radius;
                info += $" X={c.Center.X:F2} Y={c.Center.Y:F2} 直径={c.Radius * 2:F2}; ";
                drawEllipse((int)c.Center.X * 2, (int)c.Center.Y * 2, ((int)c.Radius) * 4, System.Windows.Media.Brushes.RosyBrown);
            }
            LabelInfo.Content = info;
            return count * 2;
        }
        else
        {
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
                drawEllipse((int)_pupilCenter.X * 2, (int)_pupilCenter.Y * 2, (int)pupilPx, System.Windows.Media.Brushes.Green);
                drawEllipse((int)_pupilCenter.X * 2, (int)_pupilCenter.Y * 2, (int)irisPx, System.Windows.Media.Brushes.Red);
            }
            return (int)pupilPx;
        }
    }
}
