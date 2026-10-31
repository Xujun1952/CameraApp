using OpenCvSharp;
using OpenCvSharp.WpfExtensions;

using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Shapes;

using static CameraApp.ImageViewerWindow.CaliperCircleDetector;

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
            dc.DrawLine(bluePen, new System.Windows.Point(20, 20), new System.Windows.Point(20, 420));
            dc.DrawLine(bluePen, new System.Windows.Point(20, 420), new System.Windows.Point(620, 420));
            bluePen = new Pen(Brushes.AliceBlue, 1);
            for (int i = 1; i < 11; i++)
            {
                dc.DrawLine(bluePen, new System.Windows.Point(20 + i * 60, 410), new System.Windows.Point(20 + i * 60, 420));
                dc.DrawLine(bluePen, new System.Windows.Point(20, 420 - i * 40), new System.Windows.Point(30, 420 - i * 40));
            }
            System.Windows.Point p1 = new System.Windows.Point(20, 20);
            System.Windows.Point p2 = new System.Windows.Point(300, 300);
            int x0 = 20;
            int pipul = 0;
            int pipul1 = 0;
            float pipul0 = 0;
            bool zeroSele = true;
            int k0 = int.Parse(System.IO.Path.GetFileName(fs[30]).Substring(1));
            for (int i = 30; i < 90; i++)
            {
                Debug.WriteLine($"Analyzing image: {PicName[i]}");
                ViewPic(i);

				var center = new Point2d(160.0, 120.0);
				var result = CaliperCircleDetector.Detect(
					originalMat,
					center: center,
					minR: 40,
					maxR: 80,
					lineCount: 120,
					halfWidth: 3,
					gradThresh: 15.0,
					outlierRatio: 3.0);

				//Debug.WriteLine($"圆心: ({result.Center.X:F2}, {result.Center.Y:F2})");
				//Debug.WriteLine($"半径: {result.Radius:F2}");
				//Debug.WriteLine($"有效扫描线: {result.ValidLines}");


				//pipul = DetectPupil(originalMat);
				pipul = (int)result.Radius;
				if (zeroSele && pipul == 0) continue;
                else if(pipul0 == 0)
                {
                    zeroSele = false;
                    pipul0 = pipul;
                    continue;
                }
                else if (pipul == 0) pipul= pipul1;
                else if(pipul > pipul0) pipul = pipul1;
                int k = int.Parse(System.IO.Path.GetFileName(fs[i]).Substring(1));
                Debug.WriteLine($"Extracted value k={k} r={pipul}");
                p2 = new System.Windows.Point((k - k0) / 5.55f + 20, 420 - pipul / pipul0 * 400);
                pipul1 = pipul;
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
		
		//using var display = originalMat.Clone();
		//CaliperCircleDetector.DrawResult(display, result);
		// 假设圆心已通过霍夫粗检或其他方法获得
		//var center = new Point2d(160.0, 120.0);

		/*var result = CaliperCircleDetector.Detect(
			originalMat,
			center: center,
			minR: 40,
			maxR: 80,
			lineCount: 120,
			halfWidth: 3,
			gradThresh: 15.0,
			outlierRatio: 3.0);
		
		Debug.WriteLine($"圆心: ({result.Center.X:F2}, {result.Center.Y:F2})");
		Debug.WriteLine($"半径: {result.Radius:F2}");
		Debug.WriteLine($"有效扫描线: {result.ValidLines}");
		drawEllipse((int)result.Center.X * 2, (int)result.Center.Y * 2, (int)result.Radius, System.Windows.Media.Brushes.Red);
		*/		
		

		//Cv2.ImShow("Caliper", display);
		//Cv2.WaitKey();
	}
	public static void DrawResult(Mat dst, CaliperResult result)
	{
		Scalar lineColor = new Scalar(0, 200, 255);
		Scalar circleColor = new Scalar(0, 255, 0);

		var center = new Point((int)Math.Round(result.Center.X),
							   (int)Math.Round(result.Center.Y));

		// 绘制拟合圆
		Cv2.Circle(dst, center, (int)Math.Round(result.Radius), circleColor, 2);

		// 绘制圆心
		Cv2.Circle(dst, center, 2, new Scalar(0, 0, 255), -1);

		// 绘制有效边缘点
		foreach (var p in result.EdgePoints)
		{
			var pt = new Point((int)Math.Round(p.X), (int)Math.Round(p.Y));
			Cv2.Circle(dst, pt, 1, lineColor, 1);
		}
	}
	// ====== 瞳孔检测核心逻辑 ======
	private Point _pupilCenter;
    private Point _irisCenter;
    private bool selected = true;


	//卡尺扫描法圆检测器
	public class CaliperCircleDetector
	{
		public class CaliperResult
		{
			public Point2d Center { get; set; }
			public double Radius { get; set; }
			public Point2d[] EdgePoints { get; set; }
			public int ValidLines { get; set; }
		}

		/// <summary>
		/// 卡尺扫描法：已知圆心，检测圆半径
		/// </summary>
		/// <param name="src">输入图像（灰度或彩色均可）</param>
		/// <param name="center">已知圆心</param>
		/// <param name="minR">最小半径搜索范围</param>
		/// <param name="maxR">最大半径搜索范围</param>
		/// <param name="lineCount">扫描线数量，越多越精细，建议 60~180</param>
		/// <param name="halfWidth">卡尺半宽，用于平滑梯度，建议 2~5</param>
		/// <param name="gradThresh">梯度阈值，低于此值认为该方向无有效边缘</param>
		/// <param name="outlierRatio">剔除外离群点的标准差倍数，建议 2.5~3.0</param>
		public static CaliperResult Detect(
			Mat src,
			Point2d center,
			double minR,
			double maxR,
			int lineCount = 20,
			int halfWidth = 3,
			double gradThresh = 15.0,
			double outlierRatio = 3.0)
		{
			// 确保灰度图
			Mat gray = src.Channels() == 1 ? src : new Mat();
			if (src.Channels() != 1)
				Cv2.CvtColor(src, gray, ColorConversionCodes.BGR2GRAY);

			int rows = gray.Rows;
			int cols = gray.Cols;

			var radii = new List<double>();
			var edgePoints = new List<Point2d>();

			double angleStep = Math.PI * 2.0 / lineCount;

			for (int i = 0; i < lineCount; i++)
			{
				double angle = i * angleStep;
				double cos = Math.Cos(angle);
				double sin = Math.Sin(angle);

				// 在 [minR, maxR] 范围内沿射线采样
				int sampleCount = (int)(maxR - minR) + 1;
				if (sampleCount < 3) continue;

				var samples = new double[sampleCount];
				var sampleX = new double[sampleCount];
				var sampleY = new double[sampleCount];

				bool anyValid = false;

				for (int j = 0; j < sampleCount; j++)
				{
					double r = minR + j;
					double px = center.X + r * cos;
					double py = center.Y + r * sin;

					// 双线性插值取灰度
					double v = BilinearSample(gray, px, py, rows, cols);
					if (double.IsNaN(v))
					{
						samples[j] = double.NaN;
						continue;
					}

					anyValid = true;
					samples[j] = v;
					sampleX[j] = px;
					sampleY[j] = py;
				}

				if (!anyValid) continue;

				// 计算梯度：对每个点取 [-halfWidth, +halfWidth] 邻域内的灰度差分
				int bestIdx = -1;
				double bestGrad = 0;

				for (int j = halfWidth; j < sampleCount - halfWidth; j++)
				{
					if (double.IsNaN(samples[j - halfWidth]) ||
						double.IsNaN(samples[j + halfWidth]))
						continue;

					double grad = samples[j + halfWidth] - samples[j - halfWidth];
					double absGrad = Math.Abs(grad);

					if (absGrad > bestGrad)
					{
						bestGrad = absGrad;
						bestIdx = j;
					}
				}

				if (bestIdx < 0 || bestGrad < gradThresh)
					continue;

				double rFound = minR + bestIdx;
				double ex = sampleX[bestIdx];
				double ey = sampleY[bestIdx];

				radii.Add(rFound);
				edgePoints.Add(new Point2d(ex, ey));
			}

			if (radii.Count < 6)
			{
				return new CaliperResult
				{
					Center = center,
					Radius = (minR + maxR) / 2.0,
					EdgePoints = Array.Empty<Point2d>(),
					ValidLines = 0
				};
			}

			// 剔除离群点：用中值 + MAD 稳健估计
			double medianR = Median(radii);
			var deviations = radii.Select(r => Math.Abs(r - medianR)).ToList();		
			double mad = Median(deviations) * 1.4826; // 近似标准差
			double threshold =  Math.Max(mad, 1.0) / 5;

			var inlierRadii = new List<double>();
			var inlierPoints = new List<Point2d>();

			for (int i = 0; i < radii.Count; i++)
			{
				if (Math.Abs(radii[i] - medianR) <= threshold)
				{
					inlierRadii.Add(radii[i]);
					inlierPoints.Add(edgePoints[i]);
				}
			}

			if (inlierRadii.Count < 6)
			{
				return new CaliperResult
				{
					Center = center,
					Radius = medianR,
					EdgePoints = edgePoints.ToArray(),
					ValidLines = radii.Count
				};
			}

			// 最小二乘精化：同时优化圆心和半径
			FitCircleLeastSquares(inlierPoints.ToArray(), out Point2d refinedCenter, out double refinedRadius);

			return new CaliperResult
			{
				Center = refinedCenter,
				Radius = refinedRadius,
				EdgePoints = inlierPoints.ToArray(),
				ValidLines = inlierRadii.Count
			};
		}

		/// <summary>
		/// 双线性插值采样灰度
		/// </summary>
		private static double BilinearSample(Mat gray, double x, double y, int rows, int cols)
		{
			int x0 = (int)Math.Floor(x);
			int y0 = (int)Math.Floor(y);
			int x1 = x0 + 1;
			int y1 = y0 + 1;

			if (x0 < 0 || y0 < 0 || x1 >= cols || y1 >= rows)
				return double.NaN;

			double fx = x - x0;
			double fy = y - y0;

			double v00 = gray.At<byte>(y0, x0);
			double v10 = gray.At<byte>(y0, x1);
			double v01 = gray.At<byte>(y1, x0);
			double v11 = gray.At<byte>(y1, x1);

			return (1 - fx) * (1 - fy) * v00 +
				   fx * (1 - fy) * v10 +
				   (1 - fx) * fy * v01 +
				   fx * fy * v11;
		}

		private static double Median(List<double> values)
		{
			var sorted = values.OrderBy(v => v).ToList();
			int n = sorted.Count;
			if (n == 0) return 0;
			return n % 2 == 0
				? (sorted[n / 2 - 1] + sorted[n / 2]) / 2.0
				: sorted[n / 2];
		}

		/// <summary>
		/// 最小二乘圆拟合（Kasa 方法）
		/// </summary>
		private static void FitCircleLeastSquares(
			Point2d[] points,
			out Point2d center,
			out double radius)
		{
			int n = points.Length;
			double sumX = 0, sumY = 0;
			double sumX2 = 0, sumY2 = 0, sumXY = 0;
			double sumX3 = 0, sumY3 = 0;
			double sumX2Y = 0, sumXY2 = 0;

			foreach (var p in points)
			{
				double x = p.X;
				double y = p.Y;
				double x2 = x * x;
				double y2 = y * y;

				sumX += x;
				sumY += y;
				sumX2 += x2;
				sumY2 += y2;
				sumXY += x * y;
				sumX3 += x2 * x;
				sumY3 += y2 * y;
				sumX2Y += x2 * y;
				sumXY2 += x * y2;
			}

			double A = n * sumX2 - sumX * sumX;
			double B = n * sumXY - sumX * sumY;
			double C = n * sumY2 - sumY * sumY;
			double D = 0.5 * (n * sumX3 + n * sumXY2 - sumX * sumX2 - sumX * sumY2);
			double E = 0.5 * (n * sumX2Y + n * sumY3 - sumY * sumX2 - sumY * sumY2);
			double sumR;
			double det = A * C - B * B;
			if (Math.Abs(det) < 1e-10)
			{
				// 退化情况，回退到简单平均
				center = new Point2d(sumX / n, sumY / n);
				sumR = 0;
				foreach (var p in points)
				{
					double dx = p.X - center.X;
					double dy = p.Y - center.Y;
					sumR += Math.Sqrt(dx * dx + dy * dy);
				}
				radius = sumR / n;
				return;
			}

			double cx = (D * C - B * E) / det;
			double cy = (A * E - B * D) / det;
			sumR = 0;
			foreach (var p in points)
			{
				double dx = p.X - cx;
				double dy = p.Y - cy;
				sumR += Math.Sqrt(dx * dx + dy * dy);
			}

			center = new Point2d(cx, cy);
			radius = sumR / n;


			
		}
		
		/// <summary>
		/// 在图像上绘制卡尺扫描结果
		/// </summary>
		/*
		public static void DrawResult(Mat dst, CaliperResult result, Scalar lineColor = null, Scalar circleColor = null)
		{
			lineColor ??= new Scalar(0, 200, 255);
			circleColor ??= new Scalar(0, 255, 0);

			var center = new Point((int)Math.Round(result.Center.X),
								   (int)Math.Round(result.Center.Y));

			// 绘制拟合圆
			Cv2.Circle(dst, center, (int)Math.Round(result.Radius), circleColor, 2);

			// 绘制圆心
			Cv2.Circle(dst, center, 2, new Scalar(0, 0, 255), -1);

			// 绘制有效边缘点
			foreach (var p in result.EdgePoints)
			{
				var pt = new Point((int)Math.Round(p.X), (int)Math.Round(p.Y));
				Cv2.Circle(dst, pt, 1, lineColor, 1);
			}
		}
		*/	
}

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
