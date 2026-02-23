import SwiftUI
import UIKit

struct StylePickerView: View {
    @Binding var selectedStyleIndex: Int
    @Binding var timeBigIndex: Int
    @Binding var timeColor: Color // 新增：颜色绑定
    @Binding var selectedBaseColor: Color? // 改为 Binding，状态提升到父视图
    @Binding var colorIntensity: Double    // 改为 Binding
    let availableStyles: [Int]
    
    // 用于关闭弹窗的环境变量
    @Environment(\.dismiss) var dismiss
    
    // 预设一些常用颜色
    // 包含白色，以便用户能明确选择“白色”
    let presetColors: [Color] = [.white, .black, .red, .orange, .yellow, .green, .blue, .purple, .pink]
    
    var body: some View {
        // 优化：减小间距，使布局更紧凑 (20 -> 16)
        VStack(spacing: 16) {
            // 标题栏 (替代 NavigationView)
            ZStack {
                Text("字体与颜色")
                    .font(.headline)
                
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(8)
                            .background(Color(UIColor.systemGray5))
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(availableStyles, id: \.self) { style in
                        Button(action: {
                            selectedStyleIndex = style
                        }) {
                            // 底部预览：大气一点，简化结构
                            TimeDisplayView(
                                styleIndex: style,
                                bigIndex: 0,
                                timeString: "12", // 只显示 12
                                scale: 0.22, // 稍微放大一点
                                color: .black // 预览固定为黑色
                            )
                            .frame(width: 110, height: 90) // 增大容器尺寸
                            .overlay( // 使用 overlay 绘制边框，去除复杂的嵌套
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(selectedStyleIndex == style ? Color.blue : Color.clear, lineWidth: 2)
                            )
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 5) // 修复：增加垂直内边距，防止选中边框被裁切
            }
            
            // 样式 0 专属：字体粗细调节滑块
            if selectedStyleIndex == 0 {
                GeometryReader { geo in
                    let width = geo.size.width
                    let knobSize: CGFloat = 30
                    let totalSteps: Double = 14
                    let currentProgress = Double(timeBigIndex) / totalSteps
                    
                    ZStack(alignment: .leading) {
                        Path { path in
                            let startHeight: CGFloat = 8
                            let endHeight: CGFloat = 30
                            let midY: CGFloat = 15
                            path.addArc(center: CGPoint(x: 15, y: midY), radius: startHeight/2, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
                            path.addLine(to: CGPoint(x: width - 15, y: midY - endHeight/2))
                            path.addArc(center: CGPoint(x: width - 15, y: midY), radius: endHeight/2, startAngle: .degrees(270), endAngle: .degrees(90), clockwise: false)
                            path.addLine(to: CGPoint(x: 15, y: midY + startHeight/2))
                            path.closeSubpath()
                        }
                        .fill(Color.gray.opacity(0.3))
                        
                        Circle()
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                            .frame(width: knobSize, height: knobSize)
                            .offset(x: (width - knobSize) * currentProgress)
                            .gesture(DragGesture().onChanged { value in
                                let newValue = value.location.x / (width - knobSize)
                                timeBigIndex = Int((min(max(newValue, 0), 1) * totalSteps).rounded())
                            })
                    }
                }
                .frame(height: 30)
                .padding(.horizontal, 20)
            }
            
            Divider()
                .padding(.horizontal)
            
            // 颜色选择区域 (优化后：无标题，默认在前，自定义在后)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    // 1. 常用预设颜色 (包含白色)
                    ForEach(presetColors, id: \.self) { color in
                        Button(action: {
                            // 点击预设颜色：
                            selectedBaseColor = color // 记录基准色
                            colorIntensity = 0.5      // 重置滑块到中间
                            timeColor = color         // 应用颜色
                        }) {
                            Circle()
                                .fill(color)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                                .padding(3) // 留出空隙给选中边框
                                .overlay(
                                    Circle()
                                        // 只要基准色匹配，就显示选中框（即使滑块变色了）
                                        .stroke(selectedBaseColor == color ? Color.blue : Color.clear, lineWidth: 2)
                                )
                        }
                    }
                    
                    // 2. 自定义取色器 (放在最后)
                    ColorPicker("", selection: Binding(
                        get: { timeColor },
                        set: {
                            timeColor = $0
                            selectedBaseColor = nil // 自定义颜色时，隐藏强度滑块
                        }
                    ))
                        .labelsHidden()
                        .padding(4)
                        .background(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        .padding(3)
                        .overlay(
                            // 如果当前颜色不在预设中且不是白色(原色)，则高亮自定义圆圈
                            Circle().stroke(selectedBaseColor == nil ? Color.blue : Color.clear, lineWidth: 2)
                        )
                }
                .padding(.horizontal)
                .padding(.vertical, 5) // 修复：增加垂直内边距，防止选中边框被裁切
            }
            
            // 3. 颜色强度调节 (自定义渐变滑块)
            if let baseColor = selectedBaseColor {
                GeometryReader { geo in
                    let width = geo.size.width
                    let knobSize: CGFloat = 30
                    
                    // 计算渐变的两端颜色 (浅色 -> 原色 -> 深色)
                    // 0.7 的混合系数保证不会变成纯白或纯黑，保留色彩倾向
                    let lightColor = baseColor.mix(with: .white, amount: 0.7)
                    let darkColor = baseColor.mix(with: .black, amount: 0.7)
                    
                    ZStack(alignment: .leading) {
                        // 轨道：显示从浅到深的渐变
                        Capsule()
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [lightColor, baseColor, darkColor]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(height: 30)
                            .overlay(
                                Capsule().strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                        
                        // 滑块按钮：显示当前实时颜色
                        Circle()
                            .fill(timeColor)
                            .overlay(
                                Circle().strokeBorder(Color.white, lineWidth: 2.5)
                            )
                            .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
                            .frame(width: knobSize, height: knobSize)
                            .offset(x: (width - knobSize) * colorIntensity)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        // 计算滑动比例 0...1
                                        let newValue = value.location.x / (width - knobSize)
                                        colorIntensity = min(max(newValue, 0), 1)
                                        // 实时更新颜色
                                        timeColor = calculateColor(base: baseColor, intensity: colorIntensity)
                                    }
                            )
                    }
                }
                .frame(height: 30)
                .padding(.horizontal, 20)
                .transition(.opacity) // 淡入淡出动画
            }
            
            // 优化：移除 Spacer，避免内容被顶得太高，改用 padding 控制底部留白
        }
        .padding(.bottom, 20) // 底部安全留白
    }
    
    // 计算颜色的辅助函数
    func calculateColor(base: Color, intensity: Double) -> Color {
        if intensity < 0.5 {
            // 0.0 (最浅) -> 0.5 (原色)
            // 映射到混合白色：0.7 (最浅) -> 0.0 (原色)
            let amount = (0.5 - intensity) * 2.0 * 0.7
            return base.mix(with: .white, amount: amount)
        } else {
            // 0.5 (原色) -> 1.0 (最深)
            // 映射到混合黑色：0.0 (原色) -> 0.7 (最深)
            let amount = (intensity - 0.5) * 2.0 * 0.7
            return base.mix(with: .black, amount: amount)
        }
    }
}

// 扩展：颜色混合算法
extension Color {
    func mix(with other: Color, amount: Double) -> Color {
        let uiColor1 = UIColor(self)
        let uiColor2 = UIColor(other)
        
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        // 获取颜色分量 (兼容灰度模式)
        if !uiColor1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1) {
            uiColor1.getWhite(&r1, alpha: &a1); g1 = r1; b1 = r1
        }
        if !uiColor2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2) {
            uiColor2.getWhite(&r2, alpha: &a2); g2 = r2; b2 = r2
        }
        
        let r = r1 * (1 - amount) + r2 * amount
        let g = g1 * (1 - amount) + g2 * amount
        let b = b1 * (1 - amount) + b2 * amount
        let a = a1 * (1 - amount) + a2 * amount
        
        return Color(red: r, green: g, blue: b, opacity: a)
    }
}
