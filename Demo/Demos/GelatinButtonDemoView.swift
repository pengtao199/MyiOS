import SwiftUI
#if canImport(Gelatin)
import Gelatin
#endif

struct GelatinButtonDemoView: View {
    private let capsuleHeight: CGFloat = 36
    private let horizontalPadding: CGFloat = 24
    private let circleSize: CGFloat = 44

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 20)

            Text("Native Button + Gelatin")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

            Text(effectDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            buttonRow

            Spacer(minLength: 20)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundGradient)
    }

    private var buttonRow: some View {
        HStack(spacing: 12) {
            capsuleButton
            circleButton
        }
    }

    private var capsuleButton: some View {
        Button {
            // Demo button: only visual interaction effect.
        } label: {
            Label("Continue", systemImage: "arrow.right")
                .labelStyle(.titleAndIcon)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .frame(height: capsuleHeight)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .tint(.blue)
        .modifier(LegacyGelatinModifier())
    }

    private var circleButton: some View {
        Button {
            // Demo button: only visual interaction effect.
        } label: {
            Image(systemName: "heart.fill")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: circleSize, height: circleSize)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .tint(.pink)
        .modifier(LegacyGelatinModifier())
    }

    private var effectDescription: String {
        if #available(iOS 26.0, *) {
            "iOS 26 及以上：保持原生按钮交互。"
        } else {
            "iOS 26 以下：为原生按钮叠加 Gelatin 弹性质感效果。"
        }
    }

    private var backgroundGradient: some ShapeStyle {
        LinearGradient(
            colors: [.white, Color(red: 0.94, green: 0.97, blue: 1.0)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct LegacyGelatinModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
        } else {
            #if canImport(Gelatin)
            content.gelatinEffect()
            #else
            content
            #endif
        }
    }
}

#Preview {
    GelatinButtonDemoView()
}
