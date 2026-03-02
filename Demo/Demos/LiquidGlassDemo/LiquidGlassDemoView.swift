import SwiftUI

struct LiquidGlassDemoView: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AnimatedBackdropView()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        header
                        buttonRow
                        singleCircleButtonRow
                        circleButtonRow
                        cardGrid
                    }
                    .padding(.top, max(proxy.safeAreaInsets.top, 44) + 10)
                    .padding(.horizontal, 16)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom, 16) + 8)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LiquidGlass Showcase")
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text("基于 Nikiteizzz/LiquidGlass：展示动态背景下的折射玻璃、边缘高光与色散。")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.88))
        }
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var buttonRow: some View {
        HStack(spacing: 12) {
            LiquidGlassButton(title: "Continue", systemImage: "arrow.right", tint: nil) { }
            LiquidGlassButton(title: "Favorite", systemImage: "heart.fill", tint: nil) { }
        }
    }

    private var circleButtonRow: some View {
        HStack {
            LiquidGlassCircleButtonGroup(
                items: [
                    .init(systemImage: "play.fill", action: {}),
                    .init(systemImage: "pause.fill", action: {}),
                    .init(systemImage: "backward.fill", action: {}),
                    .init(systemImage: "forward.fill", action: {})
                ],
                tint: nil
            )
            Spacer(minLength: 0)
        }
    }

    private var singleCircleButtonRow: some View {
        HStack {
            LiquidGlassCircleButton(systemImage: "play.fill", tint: nil, action: {})
            Spacer(minLength: 0)
        }
    }

    private var cardGrid: some View {
        LazyVGrid(columns: [.init(), .init()], spacing: 14) {
            LiquidGlassCard(title: "Action", systemImage: "paperplane.fill", tint: .blue)
            LiquidGlassCard(title: "Music", systemImage: "music.note", tint: nil)
            LiquidGlassCard(title: "Camera", systemImage: "camera.fill", tint: .orange)
            LiquidGlassCard(title: "Status", systemImage: "waveform.path.ecg", tint: nil)
        }
    }

    private struct AnimatedBackdropView: View {
        var body: some View {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let t = context.date.timeIntervalSinceReferenceDate

                GeometryReader { proxy in
                    let size = proxy.size

                    ZStack {
                        LinearGradient(
                            colors: [
                                Color(red: 0.07, green: 0.08, blue: 0.16),
                                Color(red: 0.10, green: 0.14, blue: 0.25),
                                Color(red: 0.16, green: 0.08, blue: 0.22)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                        floatingBlob(
                            color: .cyan,
                            size: 260,
                            x: size.width * (0.20 + 0.08 * sin(t * 0.70)),
                            y: size.height * (0.24 + 0.10 * cos(t * 0.55))
                        )

                        floatingBlob(
                            color: .pink,
                            size: 300,
                            x: size.width * (0.78 + 0.09 * cos(t * 0.63)),
                            y: size.height * (0.25 + 0.09 * sin(t * 0.72))
                        )

                        floatingBlob(
                            color: .orange,
                            size: 280,
                            x: size.width * (0.28 + 0.09 * cos(t * 0.58)),
                            y: size.height * (0.78 + 0.10 * sin(t * 0.66))
                        )

                        floatingBlob(
                            color: .mint,
                            size: 280,
                            x: size.width * (0.75 + 0.08 * sin(t * 0.61)),
                            y: size.height * (0.75 + 0.08 * cos(t * 0.69))
                        )
                    }
                }
            }
        }

        private func floatingBlob(color: Color, size: CGFloat, x: CGFloat, y: CGFloat) -> some View {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.65), color.opacity(0.0)],
                        center: .center,
                        startRadius: 20,
                        endRadius: size * 0.5
                    )
                )
                .frame(width: size, height: size)
                .position(x: x, y: y)
                .blur(radius: 30)
                .blendMode(.screen)
        }
    }
}

#Preview {
    LiquidGlassDemoView()
}
