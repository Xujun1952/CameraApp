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

using Microsoft.VisualBasic;

using OpenCvSharp;
using OpenCvSharp.Extensions;
using OpenCvSharp.WpfExtensions;

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
        int j1 = 0, j0 = 1000, k;
        foreach (string f in fs)
        {
            k = f.Length;
            if (j1 < k) j1 = k;
            if (j0 > k) j0 = k;
        }
        if (j1 == j0)
        {
            Array.Sort(fs);
        }
        else
        {
            for (var i = 0; i < fs.Length; i++)
            {
                k = fs[i].Length;
                if ((j1 - k) == 1)
                {
                    fs[i] = ReplaceLast(fs[i], "\\D", "\\D0");
                }
                else if ((j1 - k) == 2)
                {
                    fs[i] = ReplaceLast(fs[i], "\\D", "\\D00");
                }
            }
            Array.Sort(fs);
            for (var i = 0; i < fs.Length; i++)
            {
                if (fs[i].Contains("\\D00"))
                {
                    fs[i] = fs[i].Replace("\\D00", "\\D");
                }
                else if (fs[i].Contains("\\D0"))
                {
                    fs[i] = fs[i].Replace("\\D0", "\\D");
                }
            }
        }
        PicName = new string[fs.Length];
        for (int i = 0; i < fs.Length; i++)
        {
            PicName[i] = $"{i}  {System.IO.Path.GetFileName(fs[i])}";
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


    private void Img_MouseDown(object sender, MouseButtonEventArgs e)
    {
        dragStartPoint = e.GetPosition(PicImage);
        controlNum++;

        Ellipse hollowCircle = new Ellipse
        {
            Name = $"Ellipse{controlNum}",
            Width = 20,
            Height = 20,
            Stroke = System.Windows.Media.Brushes.Red,
            StrokeThickness = 1
        };

        Canvas.SetLeft(hollowCircle, dragStartPoint.X);
        Canvas.SetTop(hollowCircle, dragStartPoint.Y);
        PicCanvas.Children.Add(hollowCircle);
        Debug.WriteLine($" Control={hollowCircle.Name} Top={dragStartPoint.Y} Left={dragStartPoint.X}");

    }

    private void Img_MouseUp(object sender, MouseButtonEventArgs e)
    {
        if (dragStartPoint.X < 640) return;
        System.Windows.Point P = e.GetPosition(PicImage);
        Point P2 = new Point(P.X / 2, P.Y / 2);
        Point P1 = new Point(dragStartPoint.X / 2, dragStartPoint.Y / 2);
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

    private void GetSharp(Mat binary)
    {
        // 查找轮廓
        Point[][] contours;
        HierarchyIndex[] hierarchy;
        Cv2.FindContours(binary, out contours, out hierarchy, RetrievalModes.External, ContourApproximationModes.ApproxNone);
        Mat result = originalMat.Clone();
        // 对每个轮廓画最小外接圆
        int i = 0, x, y;
        Vec3b pixel;
        int b, g, r;
        foreach (var contour in contours)
        {
            Debug.WriteLine($"contour[{i}]length={contour.Length}");
            i++;
            if (contour.Length < 5) continue; // 点数太少跳过
            foreach (var point in contour)
            {
                x = point.X;
                y = point.Y;
                pixel = result.At<Vec3b>(y, x);
                b = pixel.Item0;   // B 通道
                g = pixel.Item1;  // G 通道
                r = pixel.Item2;    // R 通道
                Debug.WriteLine($"Point: X={x} Y={y} is {AtRange(r, g, b)}  R={r} G={g} B={b}");
                Vec3b colorRed = new Vec3b(255, 0, 0);
                result.At<Vec3b>(y, x) = colorRed;
            }
            Cv2.MinEnclosingCircle(contour, out Point2f center, out float radius);
            Cv2.Circle(result, (int)center.X, (int)center.Y, (int)radius, Scalar.Red, 1);
            Debug.WriteLine($"{i}个轮廓最小外接圆：X={center.X:F1} Y={center.Y:F1} 半径={radius:F1}");
        }
        PicImage.Source = result.ToBitmapSource();
        //Cv2.ImShow("GetSharp", result);
        result.Dispose();
    }
    private void HistGray(Mat src)
    {


        // 拆通道：bgrPlanes[0]=B, [1]=G, [2]=R
        Mat gray = new Mat();
        Cv2.CvtColor(src, gray, ColorConversionCodes.BGR2GRAY);
        // 2. 计算直方图
        int[] histSize = { 256 };
        Rangef[] ranges = { new Rangef(0, 256) };
        int[] channels = { 0 };
        Cv2.MinMaxLoc(gray, out double minVal, out double maxVal);
        System.Diagnostics.Debug.WriteLine($"Gray Min={minVal:F1} Max={maxVal:F1}");
        Mat hist = new Mat();
        Cv2.CalcHist(new Mat[] { src }, channels, null, hist, 1, histSize, ranges);
        Mat histImg = new Mat(400, 512, MatType.CV_8UC3, Scalar.Black);
        int binW = histImg.Cols / 256;
        float maxVal0 = 0;
        int maxIdx = 0;
        bool foundMax = true;
        int color = 0;
        int x;
        int se = -100;
        for (int i = 1; i < 256; i++)
        {
            if (foundMax)
            {

                if (foundMax && hist.At<float>(i) > maxVal0)
                {
                    maxVal0 = hist.At<float>(i);
                    maxIdx = i;
                }
                else if ((hist.At<float>(i) - maxVal0) < se)
                {
                    foundMax = false;
                    maxIdx = i;
                    color = 1;
                }
                else
                {
                }
                //System.Diagnostics.Debug.WriteLine($"Gray[{i}]={hist.At<float>(i):F1}");
            }
            //System.Diagnostics.Debug.WriteLine($"A[{i}]={hist.At<float>(i):F1}");
            x = i * 2;
            var b1 = new Point(x - 2, 400 - (int)hist.At<float>(i - 1));
            var b2 = new Point(x, 400 - (int)hist.At<float>(i));
            if (color == 0)
            {
                Cv2.Line(histImg, b1, b2, new Scalar(0, 0, 255), 2);
            }
            else
            {
                Cv2.Line(histImg, b1, b2, new Scalar(0, 255, 0), 2);
            }

        }
        // 3. 绘制直方图（作为图像返回）
        Cv2.ImShow("Gray Histogram", histImg);
        Mat maskBright = new Mat();
        Cv2.Threshold(gray, maskBright, maxIdx, 255, ThresholdTypes.BinaryInv);
        Cv2.ImShow("maskBright", maskBright);
        GetSharp(maskBright);
        //DetectCircles(src, gray, maskBright);
        // 释放资源
        hist.Dispose(); gray.Dispose(); histImg.Dispose(); maskBright.Dispose();
    }
    private void HistColor(Mat src)
    {


        // 拆通道：bgrPlanes[0]=B, [1]=G, [2]=R
        Mat[] bgr = new Mat[3];
        Cv2.Split(src, out bgr);

        int[] histSize = { 129 };
        Rangef[] ranges = { new Rangef(0, 128) };

        Mat histB = new Mat(), histG = new Mat(), histR = new Mat();

        Cv2.CalcHist(new[] { bgr[0] }, new[] { 0 }, null, histB, 1, histSize, ranges);
        Cv2.CalcHist(new[] { bgr[1] }, new[] { 0 }, null, histG, 1, histSize, ranges);
        Cv2.CalcHist(new[] { bgr[2] }, new[] { 0 }, null, histR, 1, histSize, ranges);

        // 归一化
        //Cv2.Normalize(histB, histB, 0, 400, NormTypes.MinMax);
        //Cv2.Normalize(histG, histG, 0, 400, NormTypes.MinMax);
        //Cv2.Normalize(histR, histR, 0, 400, NormTypes.MinMax);

        // 画到同一张图，B/G/R 分别用蓝/绿/红
        Mat histImg = new Mat(800, 256, MatType.CV_8UC3, Scalar.Black);
        int binW = histImg.Cols / 128;
        for (int i = 1; i < 128; i++)
        {
            System.Diagnostics.Debug.WriteLine($"B[{i}]={histB.At<float>(i):F1}, G[{i}]={histG.At<float>(i):F1}, R[{i}]={histR.At<float>(i):F1}");
            var b1 = new Point(binW * (i - 1), 400 - (int)histB.At<float>(i - 1));
            var b2 = new Point(binW * i, 400 - (int)histB.At<float>(i));
            Cv2.Line(histImg, b1, b2, new Scalar(255, 0, 0), 1);   // B

            var g1 = new Point(binW * (i - 1), 400 - (int)histG.At<float>(i - 1));
            var g2 = new Point(binW * i, 400 - (int)histG.At<float>(i));
            Cv2.Line(histImg, g1, g2, new Scalar(0, 255, 0), 1);   // G

            var r1 = new Point(binW * (i - 1), 400 - (int)histR.At<float>(i - 1));
            var r2 = new Point(binW * i, 400 - (int)histR.At<float>(i));
            Cv2.Line(histImg, r1, r2, new Scalar(0, 0, 255), 1);   // R
        }

        Cv2.ImShow("BGR Histogram", histImg);
    }
    private void ConnectArea(Mat binary)
    {
        // 连通组件分析（返回标签图、统计信息和质心）
        Mat labels = new Mat();          // 每个像素的标签（0=背景）
        Mat stats = new Mat();           // 每行：[x,y,width,height,area]
        Mat centroids = new Mat();       // 每行：[cx,cy]
        int numLabels = Cv2.ConnectedComponentsWithStats(binary, labels, stats, centroids, PixelConnectivity.Connectivity8);
        Mat result = originalMat.Clone();
        // 从1开始遍历（0是背景）
        for (int i = 1; i < numLabels; i++)
        {
            int area = stats.At<int>(i, (int)ConnectedComponentsTypes.Area);
            if (area > 5) // 过滤小区域
            {
                int x = stats.At<int>(i, (int)ConnectedComponentsTypes.Left);
                int y = stats.At<int>(i, (int)ConnectedComponentsTypes.Top);
                int width = stats.At<int>(i, (int)ConnectedComponentsTypes.Width);
                int height = stats.At<int>(i, (int)ConnectedComponentsTypes.Height);
                //float cx = centroids.At<float>(i, 0);
                //float cy = centroids.At<float>(i, 1);

                // 在原图上画矩形框
                Cv2.Rectangle(result, new OpenCvSharp.Rect(x, y, width, height), Scalar.Red, 1);
                Debug.WriteLine($"连接区域{i}: 面积={area}, 中心=({x + width / 2},{y + height / 2})");
            }
        }
        Cv2.ImShow("Connected Components", result);
        labels.Dispose(); stats.Dispose(); centroids.Dispose(); result.Dispose();
    }
    private void PrepWork(Mat oriMat)
    {
        if (oriMat == null) return;
        /************************************************
                Mat gray = new Mat();
                Cv2.CvtColor(oriMat, gray, ColorConversionCodes.BGR2GRAY);

                //using var clahe = Cv2.CreateCLAHE(clipLimit: 2.0, tileGridSize: new OpenCvSharp.Size(8, 8));
                Mat enhanced = new Mat();
                //clahe.Apply(gray, enhanced);

                Mat maskBright = new Mat();
                Cv2.Threshold(gray, maskBright, 0, 255, ThresholdTypes.Binary | ThresholdTypes.Otsu );
                Cv2.ImShow("maskBright", maskBright);
                Mat kernel = Cv2.GetStructuringElement(MorphShapes.Ellipse, new OpenCvSharp.Size(5, 5));
                //Cv2.Dilate(maskBright, maskBright, kernel);
                //Cv2.Inpaint(enhanced, maskBright, enhanced, 3, OpenCvSharp.InpaintTypes.Telea);

                Mat blurred = new Mat();
                int blurSize = setParam.GSparam switch { 1 => 5, 2 => 9, _ => 7 };
                Cv2.GaussianBlur(gray, blurred, new OpenCvSharp.Size(blurSize, blurSize), 1.5);

                Cv2.ImShow("Hough Input", blurred);

                CircleSegment[] circles = Cv2.HoughCircles(
                            blurred,
                            HoughModes.Gradient,
                            dp: setParam.Dp,
                            minDist: setParam.MinDist,
                            param1: setParam.Param1,
                            param2: setParam.Param2,
                            minRadius: setParam.MinRadius,
                            maxRadius: setParam.MaxRadius
                            );

                Mat result = oriMat.Clone();

                if (circles.Length > 0)
                {
                    var sorted = circles.OrderByDescending(c => c.Radius).ToArray();
                    int margin = 30;
                    int imgW = result.Width, imgH = result.Height;
                    var valid = sorted.Where(c =>
                        c.Center.X > margin && c.Center.X < imgW - margin &&
                        c.Center.Y > margin && c.Center.Y < imgH - margin
                    ).ToArray();

                    if (valid.Length > 0)
                    {
                        var pupil = valid[0];
                        Cv2.Circle(result, (int)pupil.Center.X, (int)pupil.Center.Y,
                                   (int)pupil.Radius, Scalar.Green, 2);
                        Cv2.Circle(result, (int)pupil.Center.X, (int)pupil.Center.Y,
                                   4, Scalar.Red, -1);
                        string fname = System.IO.Path.GetFileName(fs[ListPic.SelectedIndex]);
                        System.Diagnostics.Debug.WriteLine(
                            string.Format("#{0} ({1:F0},{2:F0}) R={3:F1} D={4:F1}",
                                fname, pupil.Center.X, pupil.Center.Y, pupil.Radius, pupil.Radius * 2));
                    }
                    else
                    {
                        System.Diagnostics.Debug.WriteLine("Pupil candidate at edge, filtered");
                    }

                    foreach (var c in sorted.Skip(1).Take(3))
                        Cv2.Circle(result, (int)c.Center.X, (int)c.Center.Y, (int)c.Radius, Scalar.Blue, 1);
                }
                else
                {
                    System.Diagnostics.Debug.WriteLine("HoughCircles: no circles found");
                }

                PicImage.Source = result.ToBitmapSource();

                gray.Dispose(); enhanced.Dispose(); maskBright.Dispose(); kernel.Dispose();
                blurred.Dispose(); result.Dispose();
            ***********************************************/
    }
    private void DetectCircles(Mat gray)
    {
        /************************************************************************************
                if (gray == null || src == null) return;
                //gray 灰度图像，通常用于边缘检测和形状检测。HoughCircles 是一种基于霍夫变换的圆检测算法，它在灰度图像中寻找圆形边缘。
                //maskBright 屏蔽图像，用于标记图像中需要忽略的区域（如过亮或过暗的区域）。在圆检测前，通常会使用阈值分割或其他方法生成 maskBright，以避免这些区域干扰圆检测。

                //using var clahe = Cv2.CreateCLAHE(clipLimit: 2.0, tileGridSize: new OpenCvSharp.Size(8, 8));
                //clipLimit(2.0)=对比度限制阈值。直方图均衡化时，每个灰度级的累积分布会被裁剪，防止过度拉伸导致噪声放大。值越大，对比度增强越强，但噪声也可能越明显；值越小，增强越温和。通常设为2.0~5.0。
                //tileGridSize(8×8)=分块网格大小。图像被划分为多个小块（tile），每个块独立进行直方图均衡化。Size(8, 8)表示将图像分为8行8列共64个小块。块越小，局部适应性越强，但计算量增大，可能出现块状伪影。
                //Mat enhanced = new Mat();
                //clahe.Apply(gray, enhanced);

                if (maskBright != null)
                {
                    Mat kernel = Cv2.GetStructuringElement(MorphShapes.Ellipse, new OpenCvSharp.Size(9, 9));
                    //kernel 是“内核”或“掩膜”，用于后续的图像形态学操作（如腐蚀、膨胀、开运算、闭运算等）。
                    Cv2.BitwiseNot(maskBright, maskBright);
                    Cv2.Dilate(maskBright, maskBright, kernel);
                    //Erode(腐蚀)：消除物体边界的小凸起，分离细微连接。Dilate(膨胀)：填充物体内部的小孔，连接断裂区域。
                    //Cv2.Inpaint(gray, maskBright, gray, 3, OpenCvSharp.InpaintTypes.Telea);
                    //去除水印、日期戳、污渍; 修复老照片中的划痕或折痕; 移除图像中不需要的物体（配合分割掩码）
                    //Telea 算法：从待修复区域的边界开始，逐步向内推进。每个待修复点的像素值由周围已知像素的加权平均决定，权重取决于距离和梯度方向。速度快，适合小面积修复。
                    //Navier - Stokes 算法：模拟流体流动，通过求解偏微分方程使边缘连续。对较大区域或纹理复杂的修复效果更好，但速度较慢。
                    kernel.Dispose();
                }

                Mat blurred = new Mat();
                int blurSize = setParam.GSparam switch { 1 => 5, 2 => 9, _ => 7 };
                Cv2.GaussianBlur(gray, blurred, new OpenCvSharp.Size(blurSize, blurSize), 1.5);
                //高斯滤波
                //Cv2.BitwiseNot(maskBright, maskBright);
                //Cv2.CopyTo(gray, blurred,maskBright);
                //Cv2.ImShow("gray pictrue", blurred);

                CircleSegment[] circles = Cv2.HoughCircles(
                            blurred,
                            HoughModes.Gradient,
                            dp: setParam.Dp,
                            minDist: setParam.MinDist,
                            param1: setParam.Param1,
                            param2: setParam.Param2,
                            minRadius: setParam.MinRadius,
                            maxRadius: setParam.MaxRadius
                            );
                Debug.WriteLine($"Circle num = {circles.Length}");
                //List<CircleSegment> solidCircles = new List<CircleSegment>();
                foreach (var circle in circles)
                {
                    ****************************************************
                                // 检查圆内部是否为实心（平均灰度接近原图的灰度）
                                using (Mat mask = new Mat(blurred.Size(), MatType.CV_8UC1, Scalar.Black))
                                {
                                    Cv2.Circle(mask, (int)circle.Center.X, (int)circle.Center.Y,
                                               (int)circle.Radius, Scalar.White, -1); // 填充白色

                                    // 计算圆内像素的平均灰度
                                    Scalar mean = Cv2.Mean(blurred, mask);
                                    double insideMean = mean.Val0;

                                    // 计算整个图像的全局平均灰度（作为背景参考）
                                    Scalar globalMean = Cv2.Mean(blurred);
                                    double bgMean = globalMean.Val0;

                                    // 如果圆内平均灰度明显不同于背景（例如更暗或更亮），认为是实心圆
                                    // 阈值可根据实际图像调整
                                    if (Math.Abs(insideMean - bgMean) > 20)
                                    {
                                        Cv2.Circle(blurred,
                                         (int)circle.Center.X, (int)circle.Center.Y,
                                         (int)circle.Radius,
                                         Scalar.Red,  // BGR颜色：Red
                                         thickness: 1);     // 线宽
                                    }
                                        solidCircles.Add(circle);
                                }
                    ****************************************************
                    Cv2.Circle(blurred,
                                (int)circle.Center.X, (int)circle.Center.Y,
                                (int)circle.Radius,
                                Scalar.Red,  // BGR颜色：Red
                                thickness: 1);     // 线宽
                }
                Cv2.ImShow("Detected Solid Circles", blurred);
                blurred.Dispose();
                ***************************************************/
    }

    private void PicImage_MouseRightButtonDown(object sender, MouseButtonEventArgs e)
    {
        var images = PicCanvas.Children.OfType<Ellipse>().ToList();
        foreach (Ellipse img in images)
        {
            Debug.WriteLine($"Del Control={img.Name}");
            PicCanvas.Children.Remove(img);
        }
        PicCanvas.ClearValue(Canvas.BackgroundProperty);
        PicImage.Source = originalMat.ToBitmapSource();
    }
    private void MatSubtract(Mat src)
    {
        // 2. 分离 BGR 通道（OpenCV 默认顺序为 B、G、R）
        Mat[] channels = src.Split();
        Mat blue = channels[0];   // B
        Mat green = channels[1];  // G（将被覆盖）
        Mat red = channels[2];    // R

        // 3. 将 B 和 R 转为浮点型，避免减法结果负值被截断为 0
        Mat blueFloat = new Mat();
        Mat redFloat = new Mat();
        blue.ConvertTo(blueFloat, MatType.CV_32FC1);
        red.ConvertTo(redFloat, MatType.CV_32FC1);

        // 4. 计算 B - R
        Mat diff = new Mat();
        Cv2.Subtract(blueFloat, redFloat, diff);   // diff = B - R
        //Cv2.Divide(diff, redFloat, diff);
        Cv2.Multiply(diff, 10, diff);
        // 5. 将结果饱和转换回 8-bit 无符号整数（负值变为 0，大于 255 变为 255）
        Mat newGreen = new Mat();
        diff.ConvertTo(newGreen, MatType.CV_8UC1);  // 自动饱和转换

        // 6. 将 B 和 R 通道置零
        Mat zeroMat = Mat.Zeros(src.Size(), MatType.CV_8UC1);
        channels[0] = zeroMat;  // B = 0
        channels[2] = zeroMat;  // R = 0
        channels[1] = newGreen; // G = B - R

        DetectCircles(newGreen);
        // 7. 合并三个通道得到最终图像
        //Mat result = new Mat();
        //Cv2.Add(result, src, result);
        //PicImage.Source = result.ToBitmapSource();
        // 8. 保存结果
        //string outputPath = "result_G_eq_B_minus_R_Bzero_Rzero.jpg";
        //Cv2.ImWrite(outputPath, result);
        //Console.WriteLine($"结果已保存至：{outputPath}");

        // 可选：显示结果
        Cv2.ImShow("Subtract G=B-R", newGreen);
        Mat maskBright = new Mat();
        Cv2.Threshold(newGreen, maskBright, 0, 255, ThresholdTypes.Otsu);
        Cv2.ImShow("maskBright", maskBright);
        //GetSharp(maskBright);
        //ConnectArea(maskBright);

        // 释放资源
        foreach (var ch in channels) ch?.Dispose();
        blueFloat.Dispose();
        redFloat.Dispose();
        diff.Dispose();
        newGreen.Dispose();
        zeroMat.Dispose();
        maskBright.Dispose();
        //result.Dispose();
    }
    private void MatHsv(Mat src)
    {
        // 1. 转换为 HSV 色彩空间
        var hsv = new Mat();
        Cv2.CvtColor(src, hsv, ColorConversionCodes.BGR2HSV);
        //Cv2.ImShow("HSV Image", hsv);
        // 3. 定义暗蓝绿色的 HSV 范围（H: 170~190, S: 80~200, V: 40~120）
        //    注意：OpenCV 中 H 范围是 0~179，S/V 是 0~255
        Scalar lower = new Scalar(setParam.MinR, setParam.MinG, setParam.MinB);   // 低亮度、中饱和度
        Scalar upper = new Scalar(setParam.MaxR, setParam.MaxG, setParam.MaxB);  // 高饱和度、中等亮度

        // 4. 生成二值掩膜
        var mask = new Mat();
        Cv2.InRange(hsv, lower, upper, mask);
        //Cv2.ImShow("Mask", mask);

        Debug.WriteLine($"mask 非零像素: {Cv2.CountNonZero(mask)}");
        Debug.WriteLine($"hsv 类型: {hsv.Type()}");  // 应是 CV_8UC3
        Debug.WriteLine($"mask 类型: {mask.Type()}"); // 应是 CV_8UC1
        //Cv2.WaitKey(0);
        // 5. 形态学去噪（可选）
        using var kernel = Cv2.GetStructuringElement(MorphShapes.Ellipse, new OpenCvSharp.Size(3, 3));
        Cv2.MorphologyEx(mask, mask, MorphTypes.Open, kernel);  // 开运算去噪点
        Cv2.MorphologyEx(mask, mask, MorphTypes.Close, kernel); // 闭运算填空洞
        //Cv2.ImShow("Mask", mask);
        // 6. 使用霍夫圆变换检测圆形
        //    参数：输入图像（必须为单通道灰度或二值）、检测方法、分辨率反比、最小圆心距、
        //         Canny高阈值、累加器阈值、最小半径、最大半径
        //    这里传入 mask（二值图），但 HoughCircles 内部会做边缘检测，也可以传入 mask 本身
        //    建议先对 mask 做 GaussianBlur 平滑再检测
        ConnectArea(mask);
        GetSharp(mask);
        var blurred = new Mat();
        Cv2.GaussianBlur(mask, blurred, new OpenCvSharp.Size(5, 5), 2, 2);
        //Cv2.ImShow("blurred", blurred);
        CircleSegment[] circles = Cv2.HoughCircles(
            blurred,
            HoughModes.Gradient,
            dp: 1.2,           // 累加器分辨率与图像分辨率的反比
            minDist: 100,       // 不同圆心之间的最小距离
            param1: 10,       // Canny 高阈值
            param2: 5,        // 累加器阈值（越小越容易检出假圆）
            minRadius: 2,     // 最小半径
            maxRadius: 10     // 最大半径
        );

        // 7. 在原图上绘制检测到的圆
        var result = src.Clone();
        foreach (var circle in circles)
        {
            // 画圆心
            Cv2.Circle(result, (int)circle.Center.X, (int)circle.Center.Y,
                       (int)circle.Radius, Scalar.Red, 1);
            // 标记圆心点
            Cv2.Circle(result, (int)circle.Center.X, (int)circle.Center.Y,
                       1, Scalar.DarkRed, 1);
            Debug.WriteLine($"圆心: ({circle.Center.X:F1}, {circle.Center.Y:F1}), 半径: {circle.Radius:F1}");
        }
        Mat color = src.Clone();
        // 白色区域设为红色
        color.SetTo(Scalar.Red, mask);          // binary 作为掩码（白色部分）
        Cv2.ImShow("hsv pictrue", color);
        // 8. 显示结果
        PicImage.Source = result.ToBitmapSource();
        hsv.Dispose(); result.Dispose(); blurred.Dispose(); mask.Dispose(); color.Dispose();
    }
    private void MatRGB1(Mat src)
    {
        //    BGR 顺序
        Scalar lower = new Scalar(setParam.MinR, setParam.MinG, setParam.MinB);
        Scalar upper = new Scalar(setParam.MaxR, setParam.MaxG, setParam.MaxB);

        // 4. 生成二值掩膜
        var mask = new Mat();
        Cv2.InRange(src, lower, upper, mask);
        //Cv2.ImShow("Mask", mask);

        Debug.WriteLine($"mask 非零像素: {Cv2.CountNonZero(mask)}");
        Debug.WriteLine($"hsv 类型: {src.Type()}");  // 应是 CV_8UC3
        Debug.WriteLine($"mask 类型: {mask.Type()}"); // 应是 CV_8UC1
        Mat color = src.Clone();
        // 白色区域设为红色
        color.SetTo(Scalar.Red, mask);          // binary 作为掩码（白色部分）
        //Cv2.ImShow("BGR pictrue", color);
        //var result = src.Clone();
        /***************************************************************
                using (Mat idxMat = new Mat())
                {
                    Point[] nonZeroPoints;
                    Cv2.FindNonZero(mask, idxMat);
                    nonZeroPoints = new Point[idxMat.Total()];
                    Debug.WriteLine($"Points ={nonZeroPoints.Length} {idxMat.Total()}");
                    idxMat.GetArray(out nonZeroPoints);   // 将 idxMat 内容填充到数组
                    int x, y;
                    foreach (var idx in nonZeroPoints)
                    {
                        x= idx.X; y = idx.Y;
                        byte pixelValue = mask.At<byte>(y, x);   
                        Vec3b pixel = result.At<Vec3b>(y, x);     // 返回 Vec3b 结构
                        byte blue = pixel.Item0;   // B 通道
                        byte green = pixel.Item1;  // G 通道
                        byte red = pixel.Item2;    // R 通道
                        Debug.WriteLine($"Mask NZP: X={x} Y={y} is {AtRange(red,green,blue)} value={pixelValue} src R={red} G={green} B={blue}");
                        Vec3b colorRed = new Vec3b(0, 0, 255);
                        result.At<Vec3b>(y, x) = colorRed;
                    }
                }
        ******************************************************/
        /*********************************************************
                Cv2.WaitKey(0);
                // 5. 形态学去噪（可选）
                //using var kernel = Cv2.GetStructuringElement(MorphShapes.Ellipse, new OpenCvSharp.Size(3, 3));
                //Cv2.MorphologyEx(mask, mask, MorphTypes.Open, kernel);  // 开运算去噪点
                //Cv2.MorphologyEx(mask, mask, MorphTypes.Close, kernel); // 闭运算填空洞
                //Cv2.ImShow("Mask", mask);
                // 6. 使用霍夫圆变换检测圆形
                //    参数：输入图像（必须为单通道灰度或二值）、检测方法、分辨率反比、最小圆心距、
                //         Canny高阈值、累加器阈值、最小半径、最大半径
                //    这里传入 mask（二值图），但 HoughCircles 内部会做边缘检测，也可以传入 mask 本身
                //    建议先对 mask 做 GaussianBlur 平滑再检测
        **************************************************************/
        //ConnectArea(mask);
        GetSharp(mask);
        var blurred = new Mat();
        Cv2.GaussianBlur(mask, blurred, new OpenCvSharp.Size(5, 5), 2, 2);
        //Cv2.ImShow("blurred", blurred);
        /******************************************************
                CircleSegment[] circles = Cv2.HoughCircles(
                    blurred,
                    HoughModes.Gradient,
                    dp: 1.2,           // 累加器分辨率与图像分辨率的反比
                    minDist: 100,       // 不同圆心之间的最小距离
                    param1: 10,       // Canny 高阈值
                    param2: 5,        // 累加器阈值（越小越容易检出假圆）
                    minRadius: 2,     // 最小半径
                    maxRadius: 10     // 最大半径
                );

                // 7. 在原图上绘制检测到的圆

                foreach (var circle in circles)
                {
                    // 画圆心
                    Cv2.Circle(result, (int)circle.Center.X, (int)circle.Center.Y,
                               (int)circle.Radius, Scalar.Red, 1);
                    // 标记圆心点
                    Cv2.Circle(result, (int)circle.Center.X, (int)circle.Center.Y,
                               1, Scalar.DarkRed, 1);
                    Debug.WriteLine($"圆心: ({circle.Center.X:F1}, {circle.Center.Y:F1}), 半径: {circle.Radius:F1}");
                }
        *******************************************************/

        // 8. 显示结果
        //PicImage.Source = result.ToBitmapSource();
        mask.Dispose(); color.Dispose();
    }

    private string MatRGB(Mat src)
    {
        string s = "";
        //    BGR 顺序
        int r0, g0, b0, r1, g1, b1;
        r0 = setParam.MinR; g0 = setParam.MinG; b0 = setParam.MinB;
        r1 = setParam.MaxR; g1 = setParam.MaxG; b1 = setParam.MaxB;
        int num = 0;
        var mask = new Mat();
        initTime = stopwatch.ElapsedMilliseconds;
        long t1;
        while (num < 20 || num > 60)
        {

            Scalar lower = new Scalar(b0, g0, r0);
            Scalar upper = new Scalar(b1, g1, r1);

            // 4. 生成二值掩膜          
            Cv2.InRange(src, lower, upper, mask);
            num = Cv2.CountNonZero(mask);
            t1 = stopwatch.ElapsedMilliseconds - initTime;
            Debug.WriteLine($"非零像素={num} T={t1}ms R={r0},{r1} G={g0},{g1} B={b0},{b1}");
            if (t1 > 500)
            {
                mask.Dispose();
                Debug.WriteLine("File is Error!");
                return "file is Error!";
            }
            if (num < 20)
            {
                r0--; g0--; b0--;
                r1++; g1++; b1++;
            }
            else if (num > 60)
            {
                r0++; g0++; b0++;
                r1--; g1--; b1--;
            }
        }
        // 查找轮廓
        Point[][] contours;
        HierarchyIndex[] hierarchy;
        Cv2.FindContours(mask, out contours, out hierarchy, RetrievalModes.External, ContourApproximationModes.ApproxSimple);
        Mat result = originalMat.Clone();
        // 对每个轮廓画最小外接圆
        int i = 0, x, y;
        Vec3b pixel;
        int b, g, r;
        int x0 = 0, y0 = 0, n0 = 0, xy0 = 0;
        foreach (var contour in contours)
        {
            Debug.WriteLine($"contour[{i}]length={contour.Length}");
            i++;
            if (contour.Length < 10) continue; // 点数太少跳过
            foreach (var point in contour)
            {
                x = point.X;
                y = point.Y;

                pixel = result.At<Vec3b>(y, x);
                b = pixel.Item0;   // B 通道
                g = pixel.Item1;   // G 通道
                r = pixel.Item2;   // R 通道
            }
            Cv2.MinEnclosingCircle(contour, out Point2f center, out float radius);
            x0 += (int)center.X; y0 += (int)center.Y; xy0 += (int)radius; n0++;
            Debug.WriteLine($"{i}个轮廓最小外接圆：X={center.X:F1} Y={center.Y:F1} 半径={radius:F1}");
        }
        if (n0 > 0) { x0 /= n0; y0 /= n0; xy0 /= n0; }

        // 创建掩码: 全黑单通道图像
        mask = new Mat(originalMat.Size(), MatType.CV_8UC1, Scalar.Black);
        Point p1 = new Point(x0, y0);
        // 在掩码上绘制白色实心圆
        Cv2.Circle(mask, p1, xy0, Scalar.White, -1); // thickness=-1 表示填充
        // 计算掩码区域内的均值
        Scalar mean = Cv2.Mean(originalMat, mask);
        if (x0 > 20 && y0 > 20 && x0 + 20 < originalMat.Width && y0 + 20 < originalMat.Height)
        {
            s = FindPupil(x0, y0, (int)mean.Val0, (int)mean.Val1, (int)mean.Val2);
        }
        result.Dispose();
        mask.Dispose();
        return s;
    }


    private string FindBorder(int x, int y, int h, int w)
    {
        int n = 0, y0 = y, x0 = x, b, g, r;
        string s = $"x={w},y={h};";
        while (n < 20)
        {
            Vec3b pixel = originalMat.At<Vec3b>(y0, x0);
            b = pixel.Item0;
            g = pixel.Item1;
            r = pixel.Item2;
            ; s += $"{n},{b},{g},{r}; ";
            //Debug.WriteLine($"{n} X={x0} Y={y0} R={r} G={g} B={b}");
            x0 += w; y0 += h; n++;
        }
        return s;
    }
    private string FindPupil(int x, int y, int b, int g, int r)
    {
        string s = "";

        int x0 = x, y0 = y, r0 = r, b0 = b, g0 = g;
        x0 = x; y0 = y; r0 = r; b0 = b; g0 = g;
        Debug.WriteLine($"检测圆心：X={x0} Y={y0} R={r0} G={g0} B={b0}");
        x0 = x; y0 = y; r0 = r; b0 = b; g0 = g;
        s += FindBorder(x0, y0, -1, 0) + "\r\n";
        s += FindBorder(x0, y0, -1, -1) + "\r\n";
        s += FindBorder(x0, y0, 0, -1) + "\r\n";
        s += FindBorder(x0, y0, 1, -1) + "\r\n";
        s += FindBorder(x0, y0, 1, 0) + "\r\n";
        s += FindBorder(x0, y0, 1, 1) + "\r\n";
        s += FindBorder(x0, y0, 0, 1) + "\r\n";
        s += FindBorder(x0, y0, -1, 1) + "\r\n";
        return s;
    }

    private void MatRGB0(Mat src)
    {
        //    BGR 顺序
        int r0 = setParam.MinR, g0 = setParam.MinG, b0 = setParam.MinB;
        int r1 = setParam.MaxR, g1 = setParam.MaxG, b1 = setParam.MaxB;
        int num = 0;
        long T = 0;
        var mask = new Mat();
        initTime = stopwatch.ElapsedMilliseconds;
        while (num < 40 || num > 100)
        {

            Scalar lower = new Scalar(b0, g0, r0);
            Scalar upper = new Scalar(b1, g1, r1);

            // 4. 生成二值掩膜          
            Cv2.InRange(src, lower, upper, mask);
            num = Cv2.CountNonZero(mask);
            T = stopwatch.ElapsedMilliseconds - initTime;
            if (T > 1000) break;
            //Debug.WriteLine($"非零像素={num} T={T}ms  r0={r0} g0={g0} b0={b0}   r1={r1} g1={g1} b1={b1}");

            if (num < 40)
            {
                r0--; g0--; b0--;
                //r1++; g1++; b1++;
            }
            else if (num > 100)
            {
                //r0++; g0++; b0++;
                r1--; g1--; b1--;
            }

            //initTime = stopwatch.ElapsedMilliseconds;
        }
        Debug.WriteLine($"非零像素={num} T={T}ms");
        // 查找轮廓
        Point[][] contours;
        HierarchyIndex[] hierarchy;
        Cv2.FindContours(mask, out contours, out hierarchy, RetrievalModes.External, ContourApproximationModes.ApproxSimple);
        Point[] contourP = new Point[0];
        int xy0;
        int nP = 0;
        Point p0;
        foreach (var contour in contours)
        {

            if (contour.Length > nP)
            {
                nP = contour.Length;
                contourP = contour;
            }
        }
        if (nP > 8)
        {
            /*          Vec3b pixel;
                        int b, g, r;         
                        foreach(point in contourP)
                        {
                            x = point.X;
                            y = point.Y;
                            pixel = result.At<Vec3b>(y, x);
                            b = pixel.Item0;   // B 通道
                            g = pixel.Item1;   // G 通道
                            r = pixel.Item2;   // R 通道
                            Debug.WriteLine($"Point: X={x} Y={y} is {AtRange(r, g, b)}  R={r} G={g} B={b}");
                            Vec3b colorRed = new Vec3b(255, 0, 0);
                            result.At<Vec3b>(y, x) = colorRed;
                        }*/
            Cv2.MinEnclosingCircle(contourP, out Point2f center, out float radius);
            p0 = (Point)center; xy0 = (int)radius;
            Debug.WriteLine($"最大轮廓的最小平均外接圆：X={p0.X} Y={p0.Y} 半径={xy0} T={stopwatch.ElapsedMilliseconds - initTime}ms");
            //Cv2.Circle(result, (int)center.X, (int)center.Y, (int)radius, Scalar.Red, 1);
        }
        else
        {
            mask.Dispose();
            Debug.WriteLine($"contour is small! T={stopwatch.ElapsedMilliseconds - initTime}ms");
            return;
        }
        Mat result = originalMat.Clone();
        // 创建掩码: 全黑单通道图像
        mask = new Mat(originalMat.Size(), MatType.CV_8UC1, Scalar.Black);
        // 在掩码上绘制白色实心圆
        Cv2.Circle(mask, p0, xy0, Scalar.White, -1); // thickness=-1 表示填充
        // 计算掩码区域内的均值
        Scalar mean = Cv2.Mean(originalMat, mask);
        // 消除掩码范围内的白斑
        ReplaceColorInCircle(result, mask, mean);
        Debug.WriteLine($"消除掩码范围内的白斑 T={stopwatch.ElapsedMilliseconds - initTime}ms");
        int x1 = p0.X, y1 = p0.Y;
        Vec3b cc = new Vec3b(0, 127, 0);
        result.At<Vec3b>(y1, x1) = cc;
        //调整最佳圆心
        (x1, y1) = AdjustCircleCenter(p0.X, p0.Y);
        Debug.WriteLine($"调整最佳圆心 T={stopwatch.ElapsedMilliseconds - initTime}ms");
        cc = new Vec3b(0, 0, 127);
        result.At<Vec3b>(y1, x1) = cc;
        List<Point> pp = FindPupil1(x1, y1, (int)mean.Val0, (int)mean.Val1, (int)mean.Val2);
        Cv2.MinEnclosingCircle(
            pp,
            out Point2f center0,
            out float radius0
        );
        if (streamWriter == null) Cv2.Circle(result, (int)center0.X, (int)center0.Y, (int)radius0, Scalar.AliceBlue, 1);
        if (streamWriter == null) Cv2.Circle(result, (int)x1, (int)y1, (int)xy0, Scalar.Green, 1);
        Debug.WriteLine($"找到瞳孔 T={stopwatch.ElapsedMilliseconds - initTime}ms");
        cc = new Vec3b(255, 0, 0);
        for (int j = 0; j < pp.Count; j++)
        {
            if(streamWriter == null) result.At<Vec3b>(pp[j].Y, pp[j].X) = cc;
        }
        if (streamWriter == null) PicImage.Source = result.ToBitmapSource();
        Debug.WriteLine($"瞳孔：X={center0.X:F1} Y={center0.Y:F1} 半径={radius0:F1} new=[{x1},{y1}] old=[{p0.X},{p0.Y}] T={stopwatch.ElapsedMilliseconds - initTime}ms");   
        result.Dispose();
        mask.Dispose();
    }

    /// <summary>
    /// 虹膜定位：三步逼近法。
    /// ① 粗定位眼睛中心（虹膜圆候选 + 灰度范围 + 圆环对比度，排除头发/眉毛）
    /// ② 以眼睛中心裁 ROI，剔除周围干扰
    /// ③ ROI 内精定位虹膜圆（圆环对比度选）
    /// 虹膜半径固定 25px（直径 50px，不随光照变化）。
    /// </summary>
    private bool LocateIris(Mat gray, out Point2f center, out double radius)
    {
        center = new Point2f(-1, -1);
        radius = 0;

        // 局部辅助：圆内 / 圆环平均灰度
        double MeanInCircle(Mat img, Point2f c, int r)
        {
            using Mat m = new Mat(img.Size(), MatType.CV_8UC1, Scalar.Black);
            Cv2.Circle(m, new Point((int)c.X, (int)c.Y), r, Scalar.White, -1);
            return Cv2.Mean(img, m).Val0;
        }
        double MeanInRing(Mat img, Point2f c, int rIn, int rOut)
        {
            using Mat m = new Mat(img.Size(), MatType.CV_8UC1, Scalar.Black);
            Cv2.Circle(m, new Point((int)c.X, (int)c.Y), rOut, Scalar.White, -1);
            Cv2.Circle(m, new Point((int)c.X, (int)c.Y), rIn, Scalar.Black, -1);
            return Cv2.Mean(img, m).Val0;
        }
        // 水平扇形均值：半径 rIn~rOut、水平方向 ±halfAngleDeg。
        // 只取左右（3点/9点方向），避开上下眼睑/睫毛遮挡，用于测虹膜-巩膜对比度。
        double MeanInSector(Mat img, Point2f c, double rIn, double rOut, double halfAngleDeg)
        {
            double sum = 0; int cnt = 0;
            int cx = (int)c.X, cy = (int)c.Y;
            int rr = (int)Math.Ceiling(rOut);
            double cosLim = Math.Cos(halfAngleDeg * Math.PI / 180.0);
            for (int y = cy - rr; y <= cy + rr; y++)
                for (int x = cx - rr; x <= cx + rr; x++)
                {
                    if (x < 0 || y < 0 || x >= img.Width || y >= img.Height) continue;
                    int dx = x - cx, dy = y - cy;
                    double d = Math.Sqrt(dx * dx + dy * dy);
                    if (d < rIn || d >= rOut) continue;
                    if (d < 1e-6) continue;
                    double cosA = Math.Abs(dx) / d;
                    if (cosA < cosLim) continue;
                    sum += img.At<byte>(y, x);
                    cnt++;
                }
            return cnt > 0 ? sum / cnt : 0;
        }

        // ===== ① 粗定位眼睛：虹膜圆候选，灰度范围 + 圆环对比度双重验证 =====
        Point2f eye = new Point2f(-1, -1);
        double bestScore = double.MinValue;
        CircleSegment[] circles = Cv2.HoughCircles(gray, HoughModes.Gradient,
            1.0, 30.0, 50.0, 15.0, 15, 35);   // param2 降到 15，多找候选（暗光虹膜边界弱）
        if (circles != null)
        {
            foreach (var c in circles)
            {
                double innerMean = MeanInCircle(gray, c.Center, (int)c.Radius);
                double outerMean = MeanInRing(gray, c.Center, (int)c.Radius, (int)(c.Radius + 8));
                double contrast = outerMean - innerMean;
                Debug.WriteLine($"  [眼睛候选] 圆心=({c.Center.X:F0},{c.Center.Y:F0}) R={c.Radius:F1} 内={innerMean:F0} 外={outerMean:F0} 对比={contrast:F0}");
                // 虹膜是「中等暗圆 + 亮巩膜环」：圆内 90~210（排除头发<90、皮肤/巩膜>210）
                if (innerMean < 90 || innerMean > 210) continue;
                if (contrast < 12) continue;
                if (contrast > bestScore) { bestScore = contrast; eye = c.Center; }
            }
        }

        // 粗定位失败 → 暗光回退：瞳孔暗圆（选最暗，加灰度下限避免纯头发）
        if (eye.X < 0)
        {
            double imgMean = Cv2.Mean(gray).Val0;
            CircleSegment[] pc = Cv2.HoughCircles(gray, HoughModes.Gradient,
                1.0, 20.0, 50.0, 15.0, 5, 15);
            if (pc != null)
            {
                CircleSegment bp = default; double bm = double.MaxValue;
                foreach (var c in pc)
                {
                    double m = MeanInCircle(gray, c.Center, (int)c.Radius);
                    Debug.WriteLine($"  [瞳孔候选] 圆心=({c.Center.X:F0},{c.Center.Y:F0}) R={c.Radius:F1} 内={m:F0} 整图={imgMean:F0}");
                    if (m < bm) { bm = m; bp = c; }
                }
                if (bp.Radius > 0 && bm < imgMean * 0.75)
                {
                    center = bp.Center;   // 瞳孔圆心 ≈ 眼睛中心
                    radius = 25.0;
                    return true;
                }
            }
            return false;
        }

        // ===== ② 裁 ROI：以眼睛中心裁 110×110（含虹膜+巩膜环+粗定位误差） =====
        int roiHalf = 55;
        int roiX = Math.Max(0, (int)eye.X - roiHalf);
        int roiY = Math.Max(0, (int)eye.Y - roiHalf);
        int roiW = Math.Min(gray.Width - roiX, roiHalf * 2);
        int roiH = Math.Min(gray.Height - roiY, roiHalf * 2);
        if (roiW < 40 || roiH < 40)
        {
            center = eye; radius = 25.0;
            return true;
        }
        using Mat roi = new Mat(gray, new OpenCvSharp.Rect(roiX, roiY, roiW, roiH));

        // ===== ③ ROI 内找瞳孔（最暗区域），瞳孔中心 = 虹膜中心（同心，暗光比圆环对比度可靠） =====
        Point2f irisC = eye;  // 默认退回粗定位中心
        // 限制最暗点搜索在 ROI 中心 ±8px（瞳孔半径内），排除虹膜暗斑/睫毛阴影（暗斑比瞳孔还暗会劫持 MinMaxLoc）
        double roiMinVal = double.MaxValue;
        OpenCvSharp.Point roiMinLoc = new OpenCvSharp.Point(roi.Width / 2, roi.Height / 2);
        int sC = roi.Width / 2, sR = roi.Height / 2, sRad = 8;
        for (int yy = Math.Max(0, sR - sRad); yy <= Math.Min(roi.Height - 1, sR + sRad); yy++)
            for (int xx = Math.Max(0, sC - sRad); xx <= Math.Min(roi.Width - 1, sC + sRad); xx++)
                if (roi.At<byte>(yy, xx) < roiMinVal)
                {
                    roiMinVal = roi.At<byte>(yy, xx);
                    roiMinLoc = new OpenCvSharp.Point(xx, yy);
                }

        var pupilPts = new List<Point2f>();
        using Mat roiVisited = new Mat(roi.Size(), MatType.CV_8UC1, Scalar.Black);
        var roiQueue = new Queue<OpenCvSharp.Point>();
        roiQueue.Enqueue(roiMinLoc);
        roiVisited.At<byte>(roiMinLoc.Y, roiMinLoc.X) = 255;
        double growThresh = roiMinVal + 12.0;
        while (roiQueue.Count > 0)
        {
            var p = roiQueue.Dequeue();
            pupilPts.Add(new Point2f(p.X, p.Y));
            for (int dy = -1; dy <= 1; dy++)
                for (int dx = -1; dx <= 1; dx++)
                {
                    if (dx == 0 && dy == 0) continue;
                    int nx = p.X + dx, ny = p.Y + dy;
                    if (nx < 0 || ny < 0 || nx >= roi.Width || ny >= roi.Height) continue;
                    if (roiVisited.At<byte>(ny, nx) != 0) continue;
                    if (roi.At<byte>(ny, nx) > growThresh) continue;
                    roiVisited.At<byte>(ny, nx) = 255;
                    roiQueue.Enqueue(new OpenCvSharp.Point(nx, ny));
                }
        }
        // 面积约束：瞳孔暗光≈154px、亮光≈50~78px，10~400 排除噪声点/长到整个 ROI
        if (pupilPts.Count >= 10 && pupilPts.Count <= 400)
        {
            Point2f pupilFitC; float pupilFitR;
            Cv2.MinEnclosingCircle(pupilPts, out pupilFitC, out pupilFitR);
            irisC = new Point2f(pupilFitC.X + roiX, pupilFitC.Y + roiY);
            Debug.WriteLine($"  [瞳孔中心] 面积={pupilPts.Count}px 圆心=({irisC.X:F0},{irisC.Y:F0}) R={pupilFitR:F1}");
        }
        else
        {
            Debug.WriteLine($"  [瞳孔中心] 面积异常 {pupilPts.Count}px，退回粗定位中心");
        }

        // ===== ④ 水平剖面精修：用左右缘巩膜-虹膜边界精修虹膜圆心（尤其 x 中心） =====
        double refinedR = 25.0;
        Point2f refinedC = RefineByHorizontalProfile(gray, irisC, out refinedR);
        Debug.WriteLine($"  [精修] 原圆心=({irisC.X:F0},{irisC.Y:F0}) 精修后=({refinedC.X:F0},{refinedC.Y:F0}) R={refinedR:F1}");

        center = refinedC;
        radius = 25.0;
        return true;
    }

    /// <summary>
    /// 水平剖面精修：沿虹膜圆心水平线扫灰度剖面，找左右「巩膜(亮)↔虹膜(暗)」边界，
    /// 用左右边界精修虹膜的 x 中心和半径。避开上下眼睑遮挡。
    /// </summary>
    private Point2f RefineByHorizontalProfile(Mat gray, Point2f c0, out double refinedRadius)
    {
        refinedRadius = 25.0;
        int cx = (int)c0.X, cy = (int)c0.Y;
        int y0 = Math.Max(0, cy - 3), y1 = Math.Min(gray.Height - 1, cy + 3);
        int W = gray.Width;

        // 平均灰度剖面（±3 行）
        double[] prof = new double[W];
        for (int x = 0; x < W; x++)
        {
            double s = 0; int n = 0;
            for (int y = y0; y <= y1; y++) { s += gray.At<byte>(y, x); n++; }
            prof[x] = s / n;
        }
        // 平滑（5 点移动平均）
        double[] sm = new double[W];
        for (int x = 0; x < W; x++)
        {
            int lo = Math.Max(0, x - 2), hi = Math.Min(W - 1, x + 2);
            double s = 0; for (int i = lo; i <= hi; i++) s += prof[i];
            sm[x] = s / (hi - lo + 1);
        }

        // 左边界：在 [cx-50, cx-8] 内找「灰度下降最陡」（巩膜→虹膜）
        int xL = -1; double bestL = 0;
        for (int x = Math.Max(6, cx - 50); x <= cx - 8; x++)
        {
            double g = sm[x - 1] - sm[x + 1];
            if (g > bestL) { bestL = g; xL = x; }
        }
        // 右边界：在 [cx+8, cx+50] 内找「灰度上升最陡」（虹膜→巩膜）
        int xR = -1; double bestR = 0;
        for (int x = cx + 8; x <= Math.Min(W - 6, cx + 50); x++)
        {
            double g = sm[x + 1] - sm[x - 1];
            if (g > bestR) { bestR = g; xR = x; }
        }

        if (xL > 0 && xR > 0 && xR > xL + 10)
        {
            double newR = (xR - xL) / 2.0;
            if (newR >= 22 && newR <= 28)
            {
                refinedRadius = newR;
                return new Point2f((float)((xL + xR) / 2.0), c0.Y);
            }
        }
        return c0;
    }

    /// <summary>
    /// 瞳孔分割：RANSAC 圆拟合（「弧段组成圆」思路）。
    /// 在虹膜圆内做 Canny 边缘，提取瞳孔-虹膜边界的弧段点，
    /// 用 RANSAC 找「内点最多的圆」——光斑/虹膜纹理等不共圆的离群点被自动排除。
    /// 返回瞳孔直径（像素），失败 -1。
    /// </summary>
    private double SegmentPupil(Mat gray, Point2f irisCenter, double rIris, out RotatedRect ellipse)
    {
        ellipse = default;
        double pcx = irisCenter.X, pcy = irisCenter.Y;

        // ① 虹膜圆 mask
        using Mat irisMask = new Mat(gray.Size(), MatType.CV_8UC1, Scalar.Black);
        Cv2.Circle(irisMask, new Point((int)pcx, (int)pcy), (int)(rIris * 0.9), Scalar.White, -1);

        // ② 找瞳孔中心附近最暗点（限制在虹膜圆心 ±8px 内，排除虹膜暗斑/睫毛阴影）
        double minVal = double.MaxValue;
        OpenCvSharp.Point minLoc = new OpenCvSharp.Point((int)pcx, (int)pcy);
        for (int yy = Math.Max(0, (int)pcy - 8); yy <= Math.Min(gray.Rows - 1, (int)pcy + 8); yy++)
            for (int xx = Math.Max(0, (int)pcx - 8); xx <= Math.Min(gray.Cols - 1, (int)pcx + 8); xx++)
                if (gray.At<byte>(yy, xx) < minVal)
                {
                    minVal = gray.At<byte>(yy, xx);
                    minLoc = new OpenCvSharp.Point(xx, yy);
                }

        // ②.5 反光斑填充：最暗点周围 ±12px 内，灰度 > minVal+50 的亮斑（角膜反射）填为 minVal，
        //     使瞳孔边界完整，避免亮斑在 Canny 里产生假弧段导致 RANSAC 拟合偏（亮光尤其明显）
        using Mat grayWork = gray.Clone();
        int fillR = 12;
        for (int y = Math.Max(0, minLoc.Y - fillR); y <= Math.Min(gray.Height - 1, minLoc.Y + fillR); y++)
            for (int x = Math.Max(0, minLoc.X - fillR); x <= Math.Min(gray.Width - 1, minLoc.X + fillR); x++)
                if (gray.At<byte>(y, x) > minVal + 50)
                    grayWork.At<byte>(y, x) = (byte)minVal;

        // ③ 虹膜圆内 Canny 边缘，只取最暗点周围 ±12px（瞳孔边界就在这，排除虹膜纹理远距离干扰）
        using Mat edge = new Mat();
        Cv2.Canny(grayWork, edge, 20, 60);
        using Mat edgeRoi = new Mat();
        Cv2.BitwiseAnd(edge, irisMask, edgeRoi);

        var edgePts = new List<Point2f>();
        int rSearch = 12;
        for (int y = Math.Max(0, minLoc.Y - rSearch); y <= Math.Min(gray.Rows - 1, minLoc.Y + rSearch); y++)
            for (int x = Math.Max(0, minLoc.X - rSearch); x <= Math.Min(gray.Cols - 1, minLoc.X + rSearch); x++)
                if (edgeRoi.At<byte>(y, x) != 0)
                    edgePts.Add(new Point2f(x, y));

        if (edgePts.Count < 15)
        {
            Debug.WriteLine($"    [瞳孔] RANSAC 边缘点不足 {edgePts.Count}");
            return -1;
        }

        // ④ RANSAC 圆拟合：圆心约束在虹膜圆心附近，半径 3~8px（瞳孔）
        var rng = new Random(12345);
        Point2f bestC = default; double bestR = 0; int bestIn = 0; double bestScore = double.MinValue;
        double inlierThresh = 1.5;
        int n = edgePts.Count;
        for (int iter = 0; iter < 400; iter++)
        {
            int i1 = rng.Next(n), i2 = rng.Next(n), i3 = rng.Next(n);
            if (i1 == i2 || i2 == i3 || i1 == i3) continue;
            if (!FitCircle3(edgePts[i1], edgePts[i2], edgePts[i3], out Point2f c, out double r)) continue;
            if (Math.Abs(c.X - pcx) > 10 || Math.Abs(c.Y - pcy) > 10) continue;
            if (r < 3 || r > 8) continue;
            // 灰度约束：圆内应是瞳孔（最暗），排除瞳孔领/虹膜内缘（较亮）
            double cInnerSum = 0; int cInnerCnt = 0;
            int ci0 = Math.Max(0, (int)(c.Y - r)), ci1 = Math.Min(gray.Rows - 1, (int)(c.Y + r));
            int cj0 = Math.Max(0, (int)(c.X - r)), cj1 = Math.Min(gray.Cols - 1, (int)(c.X + r));
            for (int yy = ci0; yy <= ci1; yy++)
                for (int xx = cj0; xx <= cj1; xx++)
                {
                    double ddx = xx - c.X, ddy = yy - c.Y;
                    if (ddx * ddx + ddy * ddy <= r * r) { cInnerSum += grayWork.At<byte>(yy, xx); cInnerCnt++; }
                }
            if (cInnerCnt == 0 || cInnerSum / cInnerCnt > minVal + 12) continue;
            int inliers = 0;
            foreach (var p in edgePts)
            {
                double dist = Math.Abs(Math.Sqrt((p.X - c.X) * (p.X - c.X) + (p.Y - c.Y) * (p.Y - c.Y)) - r);
                if (dist < inlierThresh) inliers++;
            }
            double score = inliers - Math.Abs(c.X - pcx) * 3;
            if (score > bestScore) { bestScore = score; bestIn = inliers; bestC = c; bestR = r; }
        }

        if (bestIn < 12)
        {
            Debug.WriteLine($"    [瞳孔] RANSAC 内点不足 {bestIn}");
            return -1;
        }

        // ⑤ 内点重拟合（质心 + 平均半径，提高精度）
        var inlierPts = new List<Point2f>();
        foreach (var p in edgePts)
        {
            double dist = Math.Abs(Math.Sqrt((p.X - bestC.X) * (p.X - bestC.X) + (p.Y - bestC.Y) * (p.Y - bestC.Y)) - bestR);
            if (dist < inlierThresh * 2) inlierPts.Add(p);
        }
        if (inlierPts.Count >= 5)
        {
            double sx = 0, sy = 0;
            foreach (var p in inlierPts) { sx += p.X; sy += p.Y; }
            double ccx = sx / inlierPts.Count, ccy = sy / inlierPts.Count;
            double sr = 0;
            foreach (var p in inlierPts) sr += Math.Sqrt((p.X - ccx) * (p.X - ccx) + (p.Y - ccy) * (p.Y - ccy));
            bestC = new Point2f((float)ccx, (float)ccy);
            bestR = sr / inlierPts.Count;
        }

        // ⑥ 输出
        double d = 2.0 * bestR;
        ellipse = new RotatedRect(bestC, new Size2f((float)d, (float)d), 0);
        Debug.WriteLine($"    [瞳孔] RANSAC 圆心=({bestC.X:F1},{bestC.Y:F1}) R={bestR:F1} D={d:F1} 内点={bestIn}");
        return d;
    }

    /// <summary>
    /// 三点拟合圆：求过三点的外接圆圆心与半径。
    /// </summary>
    private bool FitCircle3(Point2f p1, Point2f p2, Point2f p3, out Point2f center, out double radius)
    {
        center = default; radius = 0;
        double x1 = p1.X, y1 = p1.Y, x2 = p2.X, y2 = p2.Y, x3 = p3.X, y3 = p3.Y;
        double denom = 2 * (x1 * (y2 - y3) + x2 * (y3 - y1) + x3 * (y1 - y2));
        if (Math.Abs(denom) < 1e-9) return false;
        double a = x1 * x1 + y1 * y1, b = x2 * x2 + y2 * y2, c = x3 * x3 + y3 * y3;
        double cx = (a * (y2 - y3) + b * (y3 - y1) + c * (y1 - y2)) / denom;
        double cy = (a * (x3 - x2) + b * (x1 - x3) + c * (x2 - x1)) / denom;
        center = new Point2f((float)cx, (float)cy);
        radius = Math.Sqrt((x1 - cx) * (x1 - cx) + (y1 - cy) * (y1 - cy));
        return true;
    }

    /// <summary>
    /// 稳健瞳孔检测（可见光，先虹膜后瞳孔两步法）：
    /// ① HoughCircles 定位虹膜（虹膜-巩膜强边界）
    /// ② 虹膜圆内最暗分位数 → 瞳孔
    /// 返回瞳孔直径（长轴，像素），失败返回 -1。
    /// </summary>
    private double DetectPupil(Mat src, out Point2f center, out RotatedRect ellipse)
    {
        center = new Point2f(-1, -1);
        ellipse = default;

        using Mat gray = new Mat();
        Cv2.CvtColor(src, gray, ColorConversionCodes.BGR2GRAY);
        Cv2.GaussianBlur(gray, gray, new OpenCvSharp.Size(3, 3), 0);

        // ① 虹膜定位
        if (!LocateIris(gray, out Point2f irisCenter, out double rIris)) return -1;

        // ② 瞳孔分割
        double d = SegmentPupil(gray, irisCenter, rIris, out ellipse);
        if (d < 0) return -1;

        center = ellipse.Center;
        return d;
    }

    /// <summary>
    /// 批量分析所有序列帧，输出瞳孔直径-时间序列到 PupilDiameter.csv。
    /// </summary>
    private void AnalyzePupilSeries()
    {
        using var sw = new StreamWriter("PupilDiameter.csv");
        sw.WriteLine("frame,file,diameter_px,cx,cy,minor_axis_px");
        double prevD = -1;
        for (int i = 0; i < fs.Length; i++)
        {
            ViewPic(i);
            double d = DetectPupil(originalMat, out Point2f c, out RotatedRect e);
            if (d > 0 && prevD > 0 && Math.Abs(d - prevD) / prevD > 0.5)
            {
                // 帧间直径跳变 >50% 通常是眨眼/睫毛干扰，标记为异常（保留原值供人工复核）
                Debug.WriteLine($"#{i} 直径跳变 {prevD:F1}->{d:F1}px，疑似眨眼/睫毛干扰");
            }
            if (d > 0) prevD = d;
            sw.WriteLine($"{i},{System.IO.Path.GetFileName(fs[i])},{d:F2},{c.X:F1},{c.Y:F1},{Math.Min(e.Size.Width, e.Size.Height):F2}");
            Debug.WriteLine($"#{i} {System.IO.Path.GetFileName(fs[i])} D={d:F2}px");
        }
        Debug.WriteLine("瞳孔直径序列已保存到 PupilDiameter.csv");
    }

    /// <summary>
    /// 单帧调试：对当前显示的帧做两步法检测，把虹膜圆（绿色）和瞳孔椭圆（红色）叠加到图上。
    /// 便于直观判断定位是否准确。
    /// </summary>
    private void DebugSinglePupil()
    {
        if (originalMat == null || originalMat.Empty()) return;
        Debug.WriteLine($"单帧调试:第{ListPic.SelectedIndex}幅图像：");
        using Mat gray = new Mat();
        Cv2.CvtColor(originalMat, gray, ColorConversionCodes.BGR2GRAY);
        Cv2.GaussianBlur(gray, gray, new OpenCvSharp.Size(3, 3), 0);

        Mat result = originalMat.Clone();

        // ① 虹膜定位
        if (!LocateIris(gray, out Point2f irisCenter, out double rIris))
        {
            PicImage.Source = result.ToBitmapSource();
            result.Dispose();
            LabelInfo.Content = "未检测到虹膜";
            Debug.WriteLine($"单帧调试: 未检测到虹膜");
            return;
        }
        // ② 瞳孔分割（先做，得到瞳孔质心）
        double d = SegmentPupil(gray, irisCenter, rIris, out RotatedRect e);
        if (d < 0)
        {
            // 瞳孔失败，仍画虹膜圆（绿色）供参考
            Cv2.Circle(result, new Point((int)irisCenter.X, (int)irisCenter.Y), (int)rIris, Scalar.Green, 1);
            PicImage.Source = result.ToBitmapSource();
            result.Dispose();
            LabelInfo.Content = $"虹膜 R={rIris:F1}px 圆心({irisCenter.X:F0},{irisCenter.Y:F0})；未检测到瞳孔";
            Debug.WriteLine($"单帧调试: 虹膜R={rIris:F1}px, 未检测到瞳孔");
            return;
        }

        // ③ 虹膜=瞳孔同心：用瞳孔质心画虹膜圆（绿）和瞳孔圆（红）
        Point2f c = e.Center;
        Cv2.Circle(result, new Point((int)c.X, (int)c.Y), (int)rIris, Scalar.Green, 1);
        Cv2.Ellipse(result, e, new Scalar(0, 0, 255), 1);
        Cv2.Circle(result, new Point((int)c.X, (int)c.Y), 2, new Scalar(0, 0, 255), -1);

        PicImage.Source = result.ToBitmapSource();
        result.Dispose();
        LabelInfo.Content = $"虹膜 R={rIris:F1}px ｜ 瞳孔 D={d:F1}px 圆心({c.X:F0},{c.Y:F0})";
        Debug.WriteLine($"单帧调试: 虹膜R={rIris:F1}px 瞳孔D={d:F1}px 圆心=({c.X:F0},{c.Y:F0})");
    }

    private void BtnDebugSingle_Click(object sender, RoutedEventArgs e)
    {
        DebugSinglePupil();
    }

    private static void ReplaceColorInCircle(Mat src, Mat circleMask, Scalar color)
    {
        Scalar lower = new Scalar(220, 220, 220);
        Scalar upper = new Scalar(255, 255, 255);
        // 1. 创建圆形掩膜（单通道二值图像）


        // 2. 创建颜色范围掩膜
        Mat colorMask = new Mat();
        Cv2.InRange(src, lower, upper, colorMask);

        // 3. 取交集：圆内且颜色在范围内的像素
        Mat finalMask = new Mat();
        Cv2.BitwiseAnd(circleMask, colorMask, finalMask);
        //掩码膨胀
        Mat kernel = Cv2.GetStructuringElement(
            MorphShapes.Ellipse,                          // 形状：圆形
            new OpenCvSharp.Size(5, 5)        // 膨胀2个单位
        );
        Mat maskDilated = new Mat();
        Cv2.Dilate(finalMask, maskDilated, kernel, iterations: 1); //膨胀1次
        // 4. 将目标颜色应用到原图的对应位置
        src.SetTo(color, maskDilated);

        // 释放临时资源（可选，GC会处理）
        kernel.Dispose();
        maskDilated.Dispose();
        colorMask.Dispose();
        finalMask.Dispose();
    }

    private (int x2, int y2) AdjustCircleCenter(int x, int y)
    {
        Vec3b pixel;
        int x0 = x, y0 = y, x1 = x, y1 = y, x2 = x, y2 = y, n1 = 1;
        int d = 0, d0 = 0, b = 0, b0 = 0, d1 = 0, b1 = 0, n = 0;
        pixel = originalMat.At<Vec3b>(y0, x0);
        Random a = Random.Shared;
        d0 = pixel.Item2 + pixel.Item1 + pixel.Item0;
        b0 = pixel.Item0 - pixel.Item2;
        d1 = d0; b1 = b0;
        //Debug.WriteLine($"Start:  bright={d0} B-R={b0} x={x0} y={y0} r={pixel.Item2} g={pixel.Item1} b={pixel.Item0}");
        while (true)
        {
            x0 = x1 + a.Next(1, 10);
            y0 = y1 + a.Next(1, 10);
            pixel = originalMat.At<Vec3b>(y0, x0);
            d = pixel.Item2 + pixel.Item1 + pixel.Item0;
            b = pixel.Item0 - pixel.Item2;
            if (d < d0 && b > b0)
            {
                x2 += x0; y2 += y0; d1 += d; b1 += b; n1++;
                if (n1 > 1) { d0 = d1 / n1; b0 = b1 / n1; }
                //Debug.WriteLine($"adjust:n={n1}/{n}  bright={d}/{d0} B-R={b}/{b0} x={x0} y={y0} r={pixel.Item2} g={pixel.Item1} b={pixel.Item0}");
            }
            n++;
            if (n > 60) break;
        }
        if (n1 > 0)
        {
            if (n1 > 1)
            {
                x2 /= n1; y2 /= n1;
            }
            return (x2, y2);
        }
        else return (x1, y1);
    }
    private bool FindBorder0(ref int r, ref int g, ref int b, ref int x0, ref int y0, int h, int w)
    {
/*
        int x = x0, x1 = 0, y = y0, y1 = 0;
        int r0 = r, g0 = g, b0 = b;
        int oldBRless = b - r, oldRinc = 0, newBRless = 0, newRinc = 0, oldR = r;
        if (h == 0)
        {
            if (w == 1) // right
            {
                y1 = 0; x1 = x + setParam.CirL; if (x1 > originalMat.Width) x1 = originalMat.Width;
            }
            else // w == -1, left
            {
                y1 = 0; x1 = x - setParam.CirL; if (x1 < 0) x1 = 0;
            }
        }
        else if (w == 0)
        {
            if (h == 1) // down
            {
                x1 = 0; y1 = y + setParam.CirL; if (y1 > originalMat.Height) y1 = originalMat.Height;
            }
            else // h == -1, up
            {
                x1 = 0; y1 = y - setParam.CirL; if (y1 < 0) y1 = 0;
            }
        }
        else if (h == 1)
        {
            if (w == 1) // down & right
            {
                x1 = x + setParam.CirL; if (x1 > originalMat.Width) x1 = originalMat.Width;
                y1 = y + setParam.CirL; if (y1 > originalMat.Height) y1 = originalMat.Height;
            }
            else if (w == -1) // down & left
            {
                x1 = x + setParam.CirL; if (x1 > originalMat.Width) x1 = originalMat.Width;
                y1 = y - setParam.CirL; if (y1 > 0) y1 = 0;
            }
        }
        else if (h == -1)
        {
            if (w == 1) // up & right
            {
                x1 = x - setParam.CirL; if (x1 < 0) x1 = 0;
                y1 = y + setParam.CirL; if (y1 > originalMat.Height) y1 = originalMat.Height;
            }
            else // h == -1 && w == -1 up & left
            {
                x1 = x - setParam.CirL; if (x1 < 0) x1 = 0;
                y1 = y - setParam.CirL; if (y1 < 0) y1 = 0;
            }
        }
        int n = 0;
        while (n < 30)
        {
            Vec3b pixel = originalMat.At<Vec3b>(y0, x0);
            b = pixel.Item0;
            g = pixel.Item1;
            r = pixel.Item2;
            newBRless = b - r;
            newRinc = r - oldR;
            if (oldBRless - newBRless > setParam.BRless && newRinc - oldRinc > setParam.Rinc) return true;
            oldRinc = r - oldR; oldR = r;
            oldBRless = newBRless;
            Debug.WriteLine($"- X={x0} Y={y0} R={r} G={g} B={b} B-R={oldBRless - newBRless} R+={newRinc - oldRinc}");
            x0 += w; y0 += h; n++;
        }
*/
        return false;
    }
    private List<Point> FindPupil0(int x, int y, int b, int g, int r)
    {
        List<Point> pupil = new List<Point> { };

        int x0 = x, y0 = y, r0 = r, b0 = b, g0 = g;
        x0 = x; y0 = y; r0 = r; b0 = b; g0 = g;
        Debug.WriteLine($"检测圆心：X={x0} Y={y0} R={r0} G={g0} B={b0}");
        x0 = x; y0 = y; r0 = r; b0 = b; g0 = g;
        if (FindBorder0(ref r0, ref g0, ref b0, ref x0, ref y0, 1, 1))
        {
            pupil.Add(new(x0, y0));
            Debug.WriteLine($"R & B border X={x0} Y={y0} R={r0} G={g0} B={b0}");
        }
        else Debug.WriteLine("R & B not borber");
        x0 = x; y0 = y; r0 = r; b0 = b; g0 = g;
        if (FindBorder0(ref r0, ref g0, ref b0, ref x0, ref y0, 1, 0))
        {
            pupil.Add(new(x0, y0));
            Debug.WriteLine($"B border X={x0} Y={y0} R={r} G={g} B={b}");
        }
        else Debug.WriteLine("B not borber");
        x0 = x; y0 = y; r0 = r; b0 = b; g0 = g;
        if (FindBorder0(ref r0, ref g0, ref b0, ref x0, ref y0, 1, -1))
        {
            pupil.Add(new(x0, y0));
            Debug.WriteLine($"L & B border X={x0} Y={y0} R={r} G={g} B={b}");
        }
        else Debug.WriteLine("L & B not borber");
        x0 = x; y0 = y; r0 = r; b0 = b; g0 = g;
        if (FindBorder0(ref r0, ref g0, ref b0, ref x0, ref y0, 0, -1))
        {
            pupil.Add(new(x0, y0));
            Debug.WriteLine($"L border X={x0} Y={y0} R={r} G={g} B={b}");
        }
        else Debug.WriteLine("L not borber");
        x0 = x; y0 = y; r0 = r; b0 = b; g0 = g;
        if (FindBorder0(ref r0, ref g0, ref b0, ref x0, ref y0, -1, -1))
        {
            pupil.Add(new(x0, y0));
            Debug.WriteLine($"L & U border X={x0} Y={y0} R={r} G={g} B={b}");
        }
        else Debug.WriteLine("L & U not borber");
        x0 = x; y0 = y; r0 = r; b0 = b; g0 = g;
        if (FindBorder0(ref r0, ref g0, ref b0, ref x0, ref y0, -1, 0))
        {
            pupil.Add(new(x0, y0));
            Debug.WriteLine($"U border X={x0} Y={y0} R={r} G={g} B={b}");
        }
        else Debug.WriteLine("U not borber");
        x0 = x; y0 = y; r0 = r; b0 = b; g0 = g;
        if (FindBorder0(ref r0, ref g0, ref b0, ref x0, ref y0, -1, 1))
        {
            pupil.Add(new(x0, y0));
            Debug.WriteLine($"R & U border X={x0} Y={y0} R={r} G={g} B={b}");
        }
        else Debug.WriteLine("R & U not borber");
        x0 = x; y0 = y; r0 = r; b0 = b; g0 = g;
        if (FindBorder0(ref r0, ref g0, ref b0, ref x0, ref y0, 0, 1))
        {
            pupil.Add(new(x0, y0));
            Debug.WriteLine($"R border X={x0} Y={y0} R={r} G={g} B={b}");
        }
        else Debug.WriteLine("R not borber");
        return pupil;
    }

    public static int Classify(int[,] line)
    {
        // 计算暖度向量
        double[] x = Enumerable.Range(0, 20)
            .Select(i => (double)(line[i, 0] - line[i, 1]))
            .ToArray();

        // 三类判别权值 w[c][i] 和偏置 b[c]
        double[][] w = {
        new[] {-42.0,-40.9,-39.4,-37.9,-35.8,-33.3,-31.3,-28.1,-24.0,-18.3,
               -13.9,-10.1, -5.5, -0.7,  2.9,  6.2,  8.3, 10.5, 11.7, 12.8},
        new[] {-34.9,-39.8,-40.2,-21.2, 20.6, 51.3, 68.1, 67.6, 66.3, 63.9,
                59.5, 52.7, 47.6, 43.4, 37.7, 34.0, 27.2, 23.4, 14.1, 12.9},
        new[] {-36.6,-40.4,-41.6,-37.3,-35.5,-20.1, -3.4, 15.5, 28.3, 38.8,
                49.8, 57.1, 62.9, 66.3, 66.5, 64.8, 63.1, 60.4, 58.8, 57.0}
    };
        double[] b = { -3088.5, -10071.3, -11841.7 };
        int[] boundaries = { 11, 3, 6 };  // 每类对应的分界点

        // 计算三个判别分数
        double[] scores = new double[3];
        for (int c = 0; c < 3; c++)
        {
            for (int i = 0; i < 20; i++)
                scores[c] += w[c][i] * x[i];
            scores[c] += b[c];
        }

        // 取最大分数对应的类
        int type = scores[0] > scores[1] && scores[0] > scores[2] ? 0 :
                   scores[1] > scores[0] && scores[1] > scores[2] ? 1 : 2;

        return boundaries[type];
    }
    private int GetLine(int x, int y, int x1, int y1)
    {
        Vec3b pixel;
        int[,] line = new int[20, 2];
        int x0 = x, y0 = y;
        string s = "";
        for (int i = 0; i < 20; i++)
        {
            pixel = originalMat.At<Vec3b>(y0, x0);
            line[i, 1] = pixel.Item0;// B 通道
            line[i, 0] = pixel.Item2;// R 通道
            s += $"{pixel.Item0},{pixel.Item1},{pixel.Item2};";
            x0 += x1; y0 += y1;
        }
        if(streamWriter != null) streamWriter.WriteLine(s);
        return Classify(line);
    }
    private List<Point> FindPupil1(int x, int y, int b, int g, int r)
    {
        List<Point> pupil = new List<Point> { };
        int adjustP;
        //Debug.WriteLine($"检测圆心：X={x} Y={y} R={r} G={g} B={b}");
        adjustP = GetLine(x, y, 1, 1);
        pupil.Add(new(x + adjustP, y + adjustP));
        //Debug.WriteLine($"point1,1 x={x + adjustP} y={y + adjustP} +adj={adjustP}");
        adjustP = GetLine(x, y, 0, 1);
        pupil.Add(new(x, y + adjustP));
        //Debug.WriteLine($"point0,1 x={x + adjustP} y={y + adjustP} +adj={adjustP}");
        adjustP = GetLine(x, y, -1, 1);
        pupil.Add(new(x - adjustP, y + adjustP));
        //Debug.WriteLine($"point-1,1 x={x + adjustP} y={y + adjustP} +adj={adjustP}");
        adjustP = GetLine(x, y, -1, 0);
        pupil.Add(new(x - adjustP, y));
        //Debug.WriteLine($"point-1,0 x={x + adjustP} y={y + adjustP} +adj={adjustP}");
        adjustP = GetLine(x, y, -1, -1);
        pupil.Add(new(x - adjustP, y - adjustP));
        //Debug.WriteLine($"point-1,-1 x={x + adjustP} y={y + adjustP} +adj={adjustP}");
        adjustP = GetLine(x, y, 0, -1);
        pupil.Add(new(x, y - adjustP));
        //Debug.WriteLine($"point0,-1 x={x + adjustP} y={y + adjustP} +adj={adjustP}");
        adjustP = GetLine(x, y, 1, -1);
        pupil.Add(new(x + adjustP, y - adjustP));
        //Debug.WriteLine($"point1,-1 x={x + adjustP} y={y + adjustP} +adj={adjustP}");
        adjustP = GetLine(x, y, 1, 0);
        pupil.Add(new(x + adjustP, y));
        //Debug.WriteLine($"point1,0 x={x + adjustP} y={y + adjustP} +adj={adjustP}");
        return pupil;
    }

    /* 放大和缩小图片，移动图片的鼠标事件处理程序
private void Img_MouseWheel(object sender, MouseWheelEventArgs e)
{
double scaleFactor = e.Delta > 0 ? 1.1 : 0.9;
currentScale *= scaleFactor;
ScaleTf.ScaleX = currentScale;
ScaleTf.ScaleY = currentScale;
}

private void Img_MouseDown(object sender, MouseButtonEventArgs e)
{
if (e.ChangedButton == MouseButton.Left)
{
  isDragging = true;
  dragStartPoint = e.GetPosition(ScrollViewer);
  if (PicImage.CaptureMouse())
  {
      Ellipse hollowCircle = new Ellipse
      {
          Width = 20,
          Height = 20,
          Stroke = System.Windows.Media.Brushes.Red,
          StrokeThickness = 2
      };
      Canvas.SetLeft(hollowCircle, dragStartPoint.X);
      Canvas.SetTop(hollowCircle, dragStartPoint.Y);
      PicCanvas.Children.Add(hollowCircle);
  }
}
}

private void Img_MouseMove(object sender, MouseEventArgs e)
{
if (isDragging)
{
  System.Windows.Point currentPos = e.GetPosition(ScrollViewer);
  Vector offset = currentPos - dragStartPoint;
  dragStartPoint = currentPos;
  System.Diagnostics.Debug.WriteLine($"Current Position: {currentPos}, Drag Start Position: {dragStartPoint}, Offset: {offset}");
  TranslateTf.X += offset.X;
  TranslateTf.Y += offset.Y;
  System.Diagnostics.Debug.WriteLine($" TransLate.X={TranslateTf.X} .Y={TranslateTf.Y}");
}
}

private void Img_MouseUp(object sender, MouseButtonEventArgs e)
{
isDragging = false;
PicImage.ReleaseMouseCapture();
//PicCanvas.Children.Clear();
}
*/
    private void ViewPic(int i)
    {
        if (i < 0 || i >= fs.Length) return;
        if (!(originalMat is null)) originalMat.Dispose();
        var filestream = new FileStream(fs[i], FileMode.Open);
        var b = new byte[filestream.Length];
        filestream.Read(b);
        originalMat = Cv2.ImRead(fs[i], ImreadModes.Color);
        //int totalHeight = Pheight * 3 / 2;  // 确保 Pheight 为偶数
        //if (b.Length != Pwidth * totalHeight) throw new ArgumentException("NV21 数据长度不匹配");
        //Mat yuvMat = Mat.FromPixelData(totalHeight, Pwidth, MatType.CV_8UC1, b);
        //Mat bgrMat = new Mat();
        //Cv2.CvtColor(yuvMat, bgrMat, ColorConversionCodes.YUV2BGR_NV21);
        //originalMat = bgrMat.Clone(roi);
        PicImage.Source = originalMat.ToBitmapSource();
        //yuvMat.Dispose();
        //bgrMat.Dispose();
        filestream.Close();

    }
    
    bool DoAnalysis = false;
    private void BtnAnalyze_Click(object sender, RoutedEventArgs e)
    {
        if (DoAnalysis) return;
        DoAnalysis = true;
        //DetectCircles(originalMat);
        //ConnectArea(originalMat);
        //HistColor(originalMat);
        //HistGray(originalMat);
        //MatSubtract(originalMat);
        //MatRGB0(originalMat);
        //AnalysisAllPicture();
        //GetAllDataLines();
        //DrawLines();
        AnalyzePupilSeries();
        System.Threading.Thread.Sleep(3000);
        DoAnalysis = false;
    }
    private void AnalysisAllPicture()
    {
        string s = "";
        StreamWriter streamWriter = new StreamWriter($"AnalysisData");
        for (int i = 0; i < fs.Length; i++)
        {
            Debug.WriteLine(fs[i]);
            ViewPic(i);
            s += fs[i] + "\r\n" + MatRGB(originalMat);
        }
        streamWriter.WriteLine(s);
        streamWriter.Close();
        Debug.WriteLine($"save file finish [AnalysisData]");
    }
    private void BtnSetPara_Click(object sender, RoutedEventArgs e)
    {
        setParam.ParaRedraw += SetParam_ParaRedraw;
        setParam.ShowDialog();
    }

    private void SetParam_ParaRedraw(object? sender, SetParam.ParaChange e)
    {

        // 1. 转 HSV
        Mat hsv = new Mat();
        Cv2.CvtColor(originalMat, hsv, ColorConversionCodes.BGR2HSV);
        Mat[] channels = Cv2.Split(hsv);
        Mat h = channels[0];  // 0~179
        Mat s = channels[1];  // 0~255
        Mat v = channels[2];  // 0~255

        // ---------- 2. 计算当前 V 通道的均值和标准差 ----------
        Cv2.MeanStdDev(v, out Scalar meanV, out Scalar stdV);
        double curMean = meanV.Val0;
        double curStd = Math.Max(stdV.Val0, 1e-6); // 防止除零

        // ---------- 3. 调整亮度与对比度（V 通道） ----------
        // 公式：new_V = (V - curMean) * (targetContrast / curStd) + targetBrightness
        Mat vFloat = new Mat();
        Cv2.ImShow("v", v);
        v.ConvertTo(vFloat, MatType.CV_64FC1); // 转为浮点计算
        Mat newV = new Mat();
        Cv2.Subtract(vFloat, curMean, newV);
        Cv2.ImShow("newV", newV);
        Cv2.Multiply(newV,  e.Saturation / curStd, newV);
        Cv2.ImShow("newVX", newV);
        Cv2.Add(newV, e.Brightness, newV);
        Cv2.ImShow("newVY", newV);
        // 裁剪到 [0, 255] 并转回 8UC1
        Cv2.Min(newV, 255, newV);
        Cv2.Max(newV, 0, newV);
        newV.ConvertTo(v, MatType.CV_8UC1);
        Cv2.ImShow("newVZ", v);
        // ---------- 5. 合并并转回 BGR ----------
        Cv2.Merge(new Mat[] { h, s, v }, hsv);
        Mat dst = new Mat();
        Cv2.CvtColor(hsv, dst, ColorConversionCodes.HSV2BGR);
        Cv2.ImShow("dst", dst);
        PicImage.Source = dst.ToBitmapSource();
        dst.Dispose();
        vFloat.Dispose();
        newV.Dispose();
        hsv.Dispose();
        h.Dispose();
        s.Dispose();
        v.Dispose();
    }


    private void PicImage_MouseMove(object sender, MouseEventArgs e)
    {
        PicImage.Focus();
        System.Windows.Point p = e.GetPosition(PicImage);
        if (p == dragStartPoint) return;
        dragStartPoint = p;
        ReadPicPoint((int)dragStartPoint.X / 2, (int)dragStartPoint.Y / 2);
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
        ReadPicPoint((int)dragStartPoint.X / 2, (int)dragStartPoint.Y / 2);
        e.Handled = true;

    }
    
    StreamWriter streamWriter;
    private void GetAllDataLines()
    {
        streamWriter = new StreamWriter("LinesData");
        for (int i = 0; i < fs.Length; i++)
        {
            ViewPic(i);
            MatRGB0(originalMat);
        }
        streamWriter.Close();
    }

    // 修正点：
    // 1. 将 DrawLine 方法中的 Resize 相关代码移到方法体内部，并确保 pointMat 和 dst 在方法作用域内声明。
    // 2. 修正 Cv2.Resize 的调用语法错误，确保所有变量已声明且在作用域内。
    // 3. 修正方法体缺失的花括号和变量声明。

    private void DrawLines()
    {
        string s;
        string[] s1, s2;
        byte[,,] c = new byte[3, 20, 1300];
        int n = 0;
        StreamReader Sr = new StreamReader("LinesData");
        while (!Sr.EndOfStream)
        {
            s = Sr.ReadLine();
            if (s != null)
            {
                s1 = s.Split(";", StringSplitOptions.RemoveEmptyEntries);
                for (int i = 0; i < 20; i++)
                {
                    s2 = s1[i].Split(",", StringSplitOptions.RemoveEmptyEntries);
                    c[0, i, n] = byte.Parse(s2[0]);
                    c[1, i, n] = byte.Parse(s2[1]);
                    c[2, i, n] = byte.Parse(s2[2]);
                }
                n++;
            }
        }
        Sr.Close();
        // 创建一个Mat并填充像素数据
        Mat pointMat = new Mat(n, 20, MatType.CV_8UC3);
        for (int y = 0; y < n; y++)
        {
            for (int x = 0; x < 20; x++)
            {
                pointMat.Set(y, x, new Vec3b(c[0, x, y], c[1, x, y], c[2, x, y]));
            }
        }

        Mat dst = new Mat();
        Cv2.Resize(pointMat, dst, new OpenCvSharp.Size(500, 500));
        PicImage.Source = dst.ToBitmapSource();
        dst.Dispose();
        pointMat.Dispose();
    }
}

/**************************
 H:90,91, 90, 100, 90,86,99,95,             120,94,88,99,93             10,8,10,      
 S:35,55, 47, 78,  48,68,57,60,             4,39,41,53,21,              59,61,51
 V:152,145,174,163,144,151,156,149,         137,205,163,183,144,        161,162,169
 R:144,148,120,131,116,118,132,             109,111,113,109,111,
 G:166,156,155,171,154,157,170,             146,145,152,143,145,
 B:166,165,162,174,157,160,178,             147,147,146,143,147,
 
 B-R：22，17，42，33，41，42，46，          38，36，33，34，36，
 B-G：0，9，7，3，3，3，8，                 1，2，-6，0，2，

 R:110-150；G：150-170；B:155-180
 **************************/ 