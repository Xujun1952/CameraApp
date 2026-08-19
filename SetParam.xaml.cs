using System;
using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.CompilerServices;

namespace CameraApp
{
    // 参数数据模型
    public partial class SetParam : INotifyPropertyChanged
    {
        private int _minR = 110;
        private int _maxR = 150;
        private int _minG = 150;
        private int _maxG = 170;
        private int _minB = 155;
        private int _maxB = 180;
        private double _Brightness = 100;
        private double _Saturation = 50;
        private Double _Hess = 1;
        private bool _enableDebugLog = false;
        private ImageViewerWindow _imageViewerWindow;
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
        public SetParam()
        {
            InitializeComponent();
            DataContext = this;
        }


        public int MinR
        {
            get => _minR;
            set
            {
                _minR = value; OnPropertyChanged();
            }
        }

        public int MaxR
        {
            get => _maxR;
            set
            {
                _maxR = value; OnPropertyChanged();
            }
        }

        public int MinG
        {
            get => _minG;
            set
            {
                _minG = value; OnPropertyChanged();
            }
        }

        public int MinB
        {
            get => _minB;
            set
            {
                _minB = value; OnPropertyChanged();
            }
        }

        public int MaxB
        {
            get => _maxB;
            set
            {
                _maxB = value; OnPropertyChanged();
            }
        }

        public int MaxG
        {
            get => _maxG;
            set
            {
                _maxG = value; OnPropertyChanged();
            }
        }

        public double Brightness
        {
            get => _Brightness;
            set
            {
                _Brightness = value; OnPropertyChanged();
            }
        }

        public double Saturation
        {
            get => _Saturation;
            set
            {
                _Saturation = value; OnPropertyChanged();
            }
        }

        public double Hess
        {
            get => _Hess;
            set
            {
                _Hess = value; OnPropertyChanged();
            }
        }
        public event EventHandler<ParaChange>? ParaRedraw;
        public event PropertyChangedEventHandler? PropertyChanged;
        public class ParaChange : EventArgs
            {
            public int MinR { get; set; }
            public int MaxR { get; set; }
            public int MinG { get; set; }
            public int MaxG { get; set; }
            public int MinB { get; set; }
            public int MaxB { get; set; }
            public double Brightness { get; set; }
            public double Saturation { get; set; }
            public double Hess { get; set; }
        }
        protected void RaiseParaRedraw()
        {
            ParaRedraw?.Invoke(this, new ParaChange
            {
                MinR = this.MinR,
                MaxR = this.MaxR,
                MinG = this.MinG,
                MaxG = this.MaxG,
                MinB = this.MinB,
                MaxB = this.MaxB,
                Brightness = this.Brightness,
                Saturation = this.Saturation,
                Hess = this.Hess
            });
        }
        protected void OnPropertyChanged([CallerMemberName] string name = "")
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
        }

        internal new void ShowDialog()
        {
            this.Visibility = System.Windows.Visibility.Visible;
            InitializeComponent();
            _imageViewerWindow = new ImageViewerWindow();
        }

        private void BtnCancel_Click(object sender, System.Windows.RoutedEventArgs e)
        {

        }

        private void BtnOk_Click(object sender, System.Windows.RoutedEventArgs e)
        {
            RaiseParaRedraw();
        }
    }
}
    
