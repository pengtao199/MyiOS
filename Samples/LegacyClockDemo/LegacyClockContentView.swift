import SwiftUI
import Combine
import UIKit

// MARK: - 1. 基础组件：单张图片加载
// 不再进行切割，直接加载指定文件名的图片
struct SpriteImage: View {
    let imageName: String
    let color: Color // 新增：颜色参数
    
    var body: some View {
        // 修改：移除 resizable() 和 frame 限制
        // 使用图片的原始尺寸，这样冒号(colon)等小图标会保持相对于数字的正确比例
        if let path = Bundle.main.path(forResource: imageName, ofType: "png"),
           let image = UIImage(contentsOfFile: path) {
            Image(uiImage: image)
                .colorMultiply(color) // 核心：使用颜色倍增混合，保留纹理同时改变颜色
        } else {
            Color.clear // 加载失败时透明占位
        }
    }
}

// MARK: - 2. 核心逻辑：双层叠加数字视图
struct LayeredDigitView: View {
    let styleIndex: Int
    let bigIndex: Int
    let digitIndex: Int // 0-9
    let isDot: Bool     // 是否是冒号
    let color: Color    // 新增：颜色参数
    
    var body: some View {
        ZStack {
            // --- 第一层：底层文字 (time) 半透明 ---
            // 命名规则：样式_time_数字.png
            SpriteImage(imageName: getFileName(type: "time"), color: color)
                .opacity(0.5) // 还原 XML 中的半透明效果
            
            // --- 第二层：顶层特效 (t) 不透明 ---
            // 命名规则：样式_t_数字.png
            SpriteImage(imageName: getFileName(type: "t"), color: color)
        }
    }
    
    // 根据你的要求生成文件名
    func getFileName(type: String) -> String {
        let digitPart = isDot ? "dot" : "\(digitIndex)"
        
        if styleIndex == 0 {
            // Big 样式：big_粗细_t_1
            return "big_\(bigIndex)_\(type)_\(digitPart)"
        } else {
            // 普通样式：1_t_1
            return "\(styleIndex)_\(type)_\(digitPart)"
        }
    }
}

// MARK: - 3. 通用时间显示组件 (用于预览和主页)
struct TimeDisplayView: View {
    let styleIndex: Int
    let bigIndex: Int
    let timeString: String
    let scale: CGFloat
    let color: Color // 新增：颜色参数
    
    var body: some View {
        // 优化间距：XML 中原始间距为 30px。
        // 在 iOS 中，考虑到图片尺寸和屏幕密度，设置为 12pt 左右通常比较视觉平衡。
        HStack(spacing: 12) {
            ForEach(Array(timeString.enumerated()), id: \.offset) { _, char in
                if let digit = Int(String(char)) {
                    LayeredDigitView(styleIndex: styleIndex, bigIndex: bigIndex, digitIndex: digit, isDot: false, color: color)
                } else if char == ":" {
                    LayeredDigitView(styleIndex: styleIndex, bigIndex: bigIndex, digitIndex: 0, isDot: true, color: color)
                }
            }
        }
        .scaleEffect(scale)
        .frame(height: 200 * scale)
    }
}

// MARK: - 4. 主视图
struct ContentView: View {
    @State private var currentTime = Date()
    @State private var selectedStyleIndex: Int = 1 // 默认选中样式 1
    @State private var timeBigIndex: Int = 7 // 样式0的粗细 (0-14)
    @State private var timeColor: Color = .white // 新增：时间颜色，默认白色
    @State private var selectedBaseColor: Color? = .white // 新增：保存选中的基准颜色，防止弹窗重置
    @State private var colorIntensity: Double = 0.5 // 新增：保存强度值
    @State private var showStylePicker = false
    
    // 定时器，每秒更新时间
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // 假设你有多少个样式，根据你的 time 文件夹里的内容来定
    // 你可以检查 time/1, time/2... 是否存在
    let availableStyles = Array(0...7)
    
    var body: some View {
        ZStack {
            // 背景 (模拟锁屏背景)
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                
                // --- 时间显示区域 ---
                Button(action: {
                    withAnimation(.spring()) {
                        showStylePicker.toggle()
                    }
                }) {
                    // 主屏幕显示：使用较大的缩放比例 (例如 0.5，根据原图大小调整)
                    TimeDisplayView(
                        styleIndex: selectedStyleIndex,
                        bigIndex: timeBigIndex,
                        timeString: formatTime(currentTime),
                        scale: 0.5,
                        color: timeColor // 传入颜色
                    )
                }
                .buttonStyle(PlainButtonStyle()) // 去除点击灰色背景
                
                Spacer()
                Spacer()
            }
        }
        // 使用原生 Sheet 弹窗
        .sheet(isPresented: $showStylePicker) {
            StylePickerView(
                selectedStyleIndex: $selectedStyleIndex,
                timeBigIndex: $timeBigIndex,
                timeColor: $timeColor, // 传入绑定
                selectedBaseColor: $selectedBaseColor, // 传入基准色绑定
                colorIntensity: $colorIntensity,       // 传入强度绑定
                availableStyles: availableStyles
            )
            // 优化：高度微调，适配更紧凑的布局 (430->380, 350->320)
            .presentationDetents([.height(selectedStyleIndex == 0 ? 380 : 320)])
            .presentationDragIndicator(.visible)
        }
        .onReceive(timer) { input in
            currentTime = input
        }
    }
    
    // 格式化时间 HH:mm
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// 辅助扩展：圆角
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
