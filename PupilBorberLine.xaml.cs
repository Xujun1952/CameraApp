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

using Path = System.IO.Path;
using Point = OpenCvSharp.Point;
using Window = System.Windows.Window;


/// <summary>
/// 彩色线段色彩分界点查找器
/// 数据格式：每行由分号分隔的0-19个点，每个点为 B,G,R（蓝,绿,红）
/// 颜色变化规律：蓝黑色 → 棕红色
/// </summary>
namespace CameraApp;
public partial class PupilBorberLine : Window 
{
    private List<LineData> lines;
    private int AnalysisMethod;
    public struct ColorPoint
    {
        public int B, G, R;
        public ColorPoint(int b, int g, int r)
        {
            B = b; G = g; R = r;
        }
        public override string ToString() => $"({B},{G},{R})";
    }

    public class LineData
    {
        public int Index;
        public List<ColorPoint> Points;
        public int? BestBoundary; // 最佳分界点索引（该点及其之后为第二组）

        public override string ToString()
            => $"Line {Index}: {Points.Count} points, boundary at {BestBoundary}";
    }

    // ========== 主入口 ==========
    public PupilBorberLine()
    {
       
        InitializeComponent();
        RadioBt1.IsChecked = true;
        AnalysisMethod = 1;

    }

    // ========== 数据加载 ==========
    public static List<LineData> LoadData(string filePath)
    {
        var lines = new List<LineData>();
        var rawLines = File.ReadAllLines(filePath);
        for (int i = 0; i < rawLines.Length; i++)
        {
            var points = ParseLine(rawLines[i]);
            if (points.Count > 0)
            {
                lines.Add(new LineData
                {
                    Index = i,
                    Points = points
                });
            }
        }
        return lines;
    }

    private static List<ColorPoint> ParseLine(string line)
    {
        var points = new List<ColorPoint>();
        var parts = line.Split(';', StringSplitOptions.RemoveEmptyEntries);
        foreach (var part in parts)
        {
            var rgb = part.Split(',');
            if (rgb.Length == 3 &&
                int.TryParse(rgb[0], out int b) &&
                int.TryParse(rgb[1], out int g) &&
                int.TryParse(rgb[2], out int r))
            {
                points.Add(new ColorPoint(b, g, r));
            }
        }
        return points;
    }

    // ========== 方法1：最大相邻色差法 ==========
    /// <summary>
    /// 找到相邻两点间欧几里得色差最大的位置作为分界点。
    /// 分界点索引表示该点及之后属于第二组（标红色）。
    /// </summary>
    public static int FindBoundaryByMaxAdjacentDistance(List<ColorPoint> points)
    {
        if (points.Count < 2) return points.Count > 0 ? 0 : -1;

        int bestIdx = 1;
        double maxDist = 0;

        for (int i = 1; i < points.Count; i++)
        {
            double dist = ColorDistance(points[i - 1], points[i]);
            if (dist > maxDist)
            {
                maxDist = dist;
                bestIdx = i;
            }
        }

        // 如果最大色差太小（变化平缓），分界点放到中间
        if (maxDist < 5.0 && points.Count > 2)
        {
            bestIdx = points.Count / 2;
        }

        return bestIdx;
    }

    // ========== 方法2：最优方差分割法 ==========
    /// <summary>
    /// 枚举所有可能的分割位置，选择使两组组内方差之和最小的分割点。
    /// </summary>
    public static int FindBoundaryByMinVariance(List<ColorPoint> points)
    {
        int n = points.Count;
        if (n < 2) return n > 0 ? 0 : -1;
        if (n == 2) return 1;

        int bestSplit = 1;
        double minTotalVariance = double.MaxValue;

        // i 是第二组的起点索引（第一组为 [0, i-1]，第二组为 [i, n-1]）
        for (int i = 1; i < n; i++)
        {
            double var1 = ComputeGroupedColorVariance(points, 0, i - 1);
            double var2 = ComputeGroupedColorVariance(points, i, n - 1);
            double totalVar = var1 + var2;

            if (totalVar < minTotalVariance)
            {
                minTotalVariance = totalVar;
                bestSplit = i;
            }
        }

        return bestSplit;
    }

    // ========== 方法3：红色通道阈值法 ==========
    /// <summary>
    /// 基于红色通道的变化来判定分界。
    /// 蓝黑色→棕红色的核心变化是R分量增大。
    /// 使用Otsu-like方法在R通道上找最佳阈值。
    /// </summary>
    public static int FindBoundaryByRedChannel(List<ColorPoint> points)
    {
        int n = points.Count;
        if (n < 2) return n > 0 ? 0 : -1;

        // 提取R通道值
        var rValues = points.Select(p => (double)p.R).ToList();
        double rMin = rValues.Min();
        double rMax = rValues.Max();

        if (rMax - rMin < 10) return n / 2; // R通道变化不大，用中点

        // 计算R通道的一阶差分
        var diff = new double[n - 1];
        for (int i = 0; i < n - 1; i++)
            diff[i] = rValues[i + 1] - rValues[i];

        // 找差分最大的位置（R值跳跃最大处）
        int bestIdx = 1;
        double maxDiff = 0;
        for (int i = 0; i < diff.Length; i++)
        {
            if (diff[i] > maxDiff)
            {
                maxDiff = diff[i];
                bestIdx = i + 1;
            }
        }

        // 如果平均R值已经较高，分界点可能更早
        double avgR = rValues.Average();
        if (avgR > 160 && bestIdx > n / 2)
        {
            bestIdx = FindBoundaryByMaxAdjacentDistance(points);
        }

        return bestIdx;
    }

    // ========== 方法4：K-Means聚类法（k=2） ==========
    /// <summary>
    /// 使用K-Means将点聚为两类，两类交界处即为分界点。
    /// </summary>
    public static int FindBoundaryByKMeans(List<ColorPoint> points)
    {
        int n = points.Count;
        if (n < 2) return n > 0 ? 0 : -1;
        if (n == 2) return 1;

        // 初始化两个聚类中心：第一个点和最后一个点
        double[] center1 = { points[0].B, points[0].G, points[0].R };
        double[] center2 = { points[n - 1].B, points[n - 1].G, points[n - 1].R };

        int[] labels = new int[n];
        bool changed;
        int maxIter = 20;

        do
        {
            changed = false;

            // 分配每个点到最近的聚类中心
            for (int i = 0; i < n; i++)
            {
                double d1 = SquaredDistance(points[i], center1);
                double d2 = SquaredDistance(points[i], center2);
                int newLabel = d1 <= d2 ? 0 : 1;
                if (newLabel != labels[i])
                {
                    labels[i] = newLabel;
                    changed = true;
                }
            }

            // 更新聚类中心
            UpdateCenter(points, labels, 0, ref center1);
            UpdateCenter(points, labels, 1, ref center2);

            maxIter--;
        } while (changed && maxIter > 0);

        // 找到标签从0变为1的分界点
        for (int i = 1; i < n; i++)
        {
            if (labels[i] == 1 && labels[i - 1] == 0)
                return i;
        }

        // 如果所有点属于同一类，使用最大相邻色差
        return FindBoundaryByMaxAdjacentDistance(points);
    }

    // ========== 辅助函数 ==========

    private static double ColorDistance(ColorPoint a, ColorPoint b)
    {
        double dB = a.B - b.B;
        double dG = a.G - b.G;
        double dR = a.R - b.R;
        return Math.Sqrt(dB * dB + dG * dG + dR * dR);
    }

    private static double SquaredDistance(ColorPoint p, double[] center)
    {
        double dB = p.B - center[0];
        double dG = p.G - center[1];
        double dR = p.R - center[2];
        return dB * dB + dG * dG + dR * dR;
    }

    private static void UpdateCenter(List<ColorPoint> points, int[] labels, int label, ref double[] center)
    {
        double sumB = 0, sumG = 0, sumR = 0;
        int count = 0;
        for (int i = 0; i < points.Count; i++)
        {
            if (labels[i] == label)
            {
                sumB += points[i].B;
                sumG += points[i].G;
                sumR += points[i].R;
                count++;
            }
        }
        if (count > 0)
        {
            center[0] = sumB / count;
            center[1] = sumG / count;
            center[2] = sumR / count;
        }
    }

    private static double ComputeGroupedColorVariance(List<ColorPoint> points, int start, int end)
    {
        if (start > end) return 0;
        int count = end - start + 1;
        if (count <= 1) return 0;

        double meanB = 0, meanG = 0, meanR = 0;
        for (int i = start; i <= end; i++)
        {
            meanB += points[i].B;
            meanG += points[i].G;
            meanR += points[i].R;
        }
        meanB /= count;
        meanG /= count;
        meanR /= count;

        double variance = 0;
        for (int i = start; i <= end; i++)
        {
            double dB = points[i].B - meanB;
            double dG = points[i].G - meanG;
            double dR = points[i].R - meanR;
            variance += dB * dB + dG * dG + dR * dR;
        }
        return variance / count;
    }

    // ========== 评估与输出 ==========
    static double mean;
    static double median;
    static double stdDev;
    private static void EvaluateMethod(List<LineData> lines,
        Func<List<ColorPoint>, int> method, string methodName)
    {
        var boundaries = new int[lines.Count];
        for (int i = 0; i < lines.Count; i++)
        {
            boundaries[i] = method(lines[i].Points);
        }

        mean = boundaries.Average();
        median = Median(boundaries);
        int mode = Mode(boundaries);
        stdDev = StandardDeviation(boundaries, mean);

        Debug.WriteLine($"  方法: {methodName}");
        Debug.WriteLine($"  平均分界点: {mean:F2}");
        Debug.WriteLine($"  中位数:     {median:F1}");
        Debug.WriteLine($"  众数:       {mode}");
        Debug.WriteLine($"  标准差:     {stdDev:F2}");
    }

    private static void PrintConsensus(List<LineData> lines)
    {
        var methods = new Func<List<ColorPoint>, int>[]
        {
            FindBoundaryByMaxAdjacentDistance,
            FindBoundaryByMinVariance,
            FindBoundaryByRedChannel,
            FindBoundaryByKMeans
        };

        // 对每条线，取4种方法结果的众数
        for (int i = 0; i < lines.Count; i++)
        {
            var votes = methods.Select(m => m(lines[i].Points)).ToList();
            int consensus = votes.GroupBy(x => x)
                .OrderByDescending(g => g.Count())
                .ThenBy(g => Math.Abs(g.Key - lines[i].Points.Count / 2))
                .First().Key;
            lines[i].BestBoundary = consensus;
        }

        var finalBounds = lines.Select(l => l.BestBoundary.Value).ToList();
        Debug.WriteLine($"  综合众数分界点: {Mode(finalBounds.ToArray())}");
        Debug.WriteLine($"  平均分界点:     {finalBounds.Average():F2}");
        Debug.WriteLine($"  中位数:         {Median(finalBounds.ToArray()):F1}");
    }

    private static void PrintDetailed(List<LineData> lines)
    {
        foreach (var line in lines)
        {
            int bound = line.BestBoundary ?? 0;
            var group1 = line.Points.Take(bound).ToList();
            var group2 = line.Points.Skip(bound).ToList();

            Debug.WriteLine($"\n  Line {line.Index}: {line.Points.Count}个点, 分界点={bound}");
            Console.Write($"    蓝黑组 ({group1.Count}个): ");
            Debug.WriteLine(string.Join(" ", group1.Select(p => $"{p}")));
            Console.Write($"    棕红组 ({group2.Count}个): ");
            Debug.WriteLine(string.Join(" ", group2.Select(p => $"{p}")));

            // 判断分界质量
            if (group1.Count > 0 && group2.Count > 0)
            {
                double avgR1 = group1.Average(p => p.R);
                double avgR2 = group2.Average(p => p.R);
                Debug.WriteLine($"    平均R值: 蓝黑组={avgR1:F0}, 棕红组={avgR2:F0}, 差值={avgR2 - avgR1:F0}");
            }
        }
    }

    private static void SaveResults(List<LineData> lines, string originalPath)
    {
        string dir = Path.GetDirectoryName(originalPath) ?? ".";
        string resultPath = Path.Combine(dir, "LinesData_分界结果.txt");

        using var writer = new StreamWriter(resultPath);
        writer.WriteLine("LineIndex\tPoints\tBoundary\tAvgR_Group1\tAvgR_Group2\tR_Diff");

        foreach (var line in lines)
        {
            int bound = line.BestBoundary ?? 0;
            var g1 = line.Points.Take(bound).ToList();
            var g2 = line.Points.Skip(bound).ToList();
            double r1 = g1.Count > 0 ? g1.Average(p => p.R) : 0;
            double r2 = g2.Count > 0 ? g2.Average(p => p.R) : 0;

            writer.WriteLine($"{line.Index}\t{line.Points.Count}\t{bound}\t{r1:F1}\t{r2:F1}\t{r2 - r1:F1}");
        }

        Debug.WriteLine($"\n结果已保存到: {resultPath}");
    }

    // ========== 统计函数 ==========

    private static double Median(int[] values)
    {
        var sorted = values.OrderBy(x => x).ToArray();
        int n = sorted.Length;
        if (n % 2 == 0)
            return (sorted[n / 2 - 1] + sorted[n / 2]) / 2.0;
        return sorted[n / 2];
    }

    private static int Mode(int[] values)
    {
        return values.GroupBy(x => x)
            .OrderByDescending(g => g.Count())
            .First().Key;
    }

    private static double StandardDeviation(int[] values, double mean)
    {
        if (values.Length <= 1) return 0;
        double sumSq = values.Sum(v => (v - mean) * (v - mean));
        return Math.Sqrt(sumSq / (values.Length - 1));
    }
    // ========== UI事件处理 ==========
    private void LoadFile_Click(object sender, RoutedEventArgs e)
    {
        string filePath = "LinesData";
        DrawLine.IsEnabled = false;
        if (!File.Exists(filePath))
        {
            Debug.WriteLine($"文件不存在: {filePath}");
            return;
        }
        DrawLine.IsEnabled = true;
        lines = LoadData(filePath);
        Debug.WriteLine($"加载了 {lines.Count} 条线段数据\n");
    }

    private void DrawLine_Click(object sender, RoutedEventArgs e)
    {
        switch (AnalysisMethod)
        {
            case 1:
                EvaluateMethod(lines, FindBoundaryByMaxAdjacentDistance, "最大相邻色差");
                break;
            case 2:
                EvaluateMethod(lines, FindBoundaryByMinVariance, "最优方差分割");
                break;
            case 3:
                EvaluateMethod(lines, FindBoundaryByRedChannel, "红色通道阈值");
                break;
            case 4:
                EvaluateMethod(lines, FindBoundaryByKMeans, "K-Means聚类");
                break;
        }

        // 综合结果：取众数
        //Debug.WriteLine("\n==================== 综合结果（多方法投票） ====================");
        //PrintConsensus(lines);

        // 详细输出每条线的分界点
        //Debug.WriteLine("\n==================== 每条线详细信息 ====================");
        //PrintDetailed(lines);

        // 保存结果
        //SaveResults(lines, "AnalysisResult");
        int n = lines.Count;
        Mat pointMat = new Mat(n, 20, MatType.CV_8UC3);
        Vec3b colorA = new Vec3b(0, 255, 255); // 黄色
        Vec3b colorB = new Vec3b(255, 0, 255); // 红色
        for (int y = 0; y < n; y++)
        {
            for (int x = 0; x < 20; x++)
            {
                pointMat.Set(y, x, new Vec3b(
                    (byte)lines[y].Points[x].B,
                    (byte)lines[y].Points[x].G,
                    (byte)lines[y].Points[x].R)
                );                
            }
            pointMat.Set(y,(int)mean, colorB); // 标记分界点
            pointMat.Set(y,(int)median, colorA); // 标记中位数点
        }
      
        Mat dst = new Mat();
        Cv2.Resize(pointMat, dst, new OpenCvSharp.Size(500, 500));
        Pic.Source = dst.ToBitmapSource();
        dst.Dispose();
        pointMat.Dispose();

    }

    private void RadioBt_Checked(object sender, RoutedEventArgs e)
    {
        var radioButton = sender as RadioButton;
        while (radioButton != null)
        {
            if (radioButton.IsChecked == true)
            {
                AnalysisMethod = int.Parse(radioButton.Tag.ToString());
                Debug.WriteLine($"选择了分析方法: {AnalysisMethod}");
                break;
            }
            
        }
    }
}

