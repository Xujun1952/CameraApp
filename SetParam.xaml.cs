using System;
using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.CompilerServices;

namespace CameraApp
{

    public enum HoughMethod
    {
        Gradient,      // 对应 HoughModes.Gradient
        GradientAlt,   // 对应 HoughModes.GradientAlt
                       // 可扩展其他方法，但霍夫圆只有这两种
    }
    public partial class SetParam : INotifyPropertyChanged
    {
        private HoughMethod _method = HoughMethod.Gradient;
        private float _dp = 1f;
        private int _minDist = 300;
        private int _Param1 = 300;
        private float _Param2 = 0.8f;
        private int _minRadius = 2;
        private int _maxRadius = 30;
         

        public SetParam()
        {
            InitializeComponent();
            DataContext = this;
            //this.Visibility = System.Windows.Visibility.Visible;
        }
        public float Dp
        {
            get => _dp;
            set
            {
                _dp = value; OnPropertyChanged();
            }
        }
        public int MaxRadius
        {
            get => (int)_maxRadius;
            set
            {
                _maxRadius = value; OnPropertyChanged();
            }
        }
        public int MinRadius
        {
            get => _minRadius;
            set
            {
                _minRadius = value; OnPropertyChanged();
            }
        }
        public int Param1
        {
            get => _Param1;
            set
            {
                _Param1 = value; OnPropertyChanged();
            }
        }
        public float Param2
        {
            get => _Param2;
            set
            {
                _Param2 = value; OnPropertyChanged();
            }
        }
        public int MinDist
        {
            get => _minDist;
            set
            {
                _minDist = value; OnPropertyChanged();
            }
        }
        public HoughMethod Method
        {
            get => _method;
            set
            {
                _method = value; OnPropertyChanged();
            }
        }
       
        public event PropertyChangedEventHandler? PropertyChanged;
        public event EventHandler<ParaChange>? ParaRedraw;

        public class ParaChange : EventArgs
        {
            public HoughMethod Method { get; set; }
            public float Dp { get; set; }
            public int MaxRadius { get; set; }
            public int MinRadius { get; set; }
            public int Param1 { get; set; }
            public float Param2 { get; set; }
            public int MinDist { get; set; }
        }
        protected void RaiseParaRedraw()
        {
            ParaRedraw?.Invoke(this, new ParaChange
            {
                Method = this.Method,
                Dp = this.Dp,
                MaxRadius = this.MaxRadius,
                MinRadius = this.MinRadius,
                Param1 = this.Param1,
                Param2 = this.Param2,
                MinDist = this.MinDist
            });
        }
        protected void OnPropertyChanged([CallerMemberName] string name = "")
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
        }
        
        private void BtnCancel_Click(object sender, System.Windows.RoutedEventArgs e)
        {
           this.Visibility = System.Windows.Visibility.Hidden;
        }

        private void BtnOk_Click(object sender, System.Windows.RoutedEventArgs e)
        {
            RaiseParaRedraw();
        }
    }
}
    
