import SwiftUI
import LiquidGlass

private enum LiquidGlassDesign {
    static let cornerRadius: CGFloat = 22
    static let tintOpacity: CGFloat = 0.10
    static let glassType = LiquidGlassView.GlassType.custom(height: 20, amount: 60, depthEffect: 1)

    static func config(tint: Color?) -> LiquidGlassView.Configuration {
        .init(corner: cornerRadius, tint: (tint ?? .clear).opacity(tintOpacity))
    }
}

struct LiquidGlassCard: View {
    let title: String
    let systemImage: String
    let tint: Color?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 126)
        .liquidGlassBackground(LiquidGlassDesign.config(tint: tint), glassType: LiquidGlassDesign.glassType)
    }
}

struct LiquidGlassButton: View {
    let title: String
    let systemImage: String
    let tint: Color?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
        }
        .buttonStyle(.plain)
        .liquidGlassBackground(LiquidGlassDesign.config(tint: tint), glassType: LiquidGlassDesign.glassType)
    }
}

struct LiquidGlassCircleButtonItem: Identifiable {
    let id = UUID()
    let systemImage: String
    let action: () -> Void
}

struct LiquidGlassCircleButton: View {
    let systemImage: String
    let tint: Color?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
        }
        .buttonStyle(.plain)
        .liquidGlassBackground(
            .init(corner: 999, tint: (tint ?? .clear).opacity(0.08)),
            glassType: LiquidGlassDesign.glassType
        )
    }
}

struct LiquidGlassCircleButtonGroup: View {
    let items: [LiquidGlassCircleButtonItem]
    let tint: Color?

    var body: some View {
        HStack(spacing: 10) {
            ForEach(items) { item in
                Button(action: item.action) {
                    Image(systemName: item.systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .liquidGlassBackground(
            .init(corner: 999, tint: (tint ?? .clear).opacity(0.08)),
            glassType: LiquidGlassDesign.glassType
        )
    }
}
