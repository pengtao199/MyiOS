//
//  IconShowcaseDemoView.swift
//  Demo
//
//  Created by Codex on 2026/2/24.
//

import LiquidGlassKit
import SwiftUI
import UIKit

struct IconShowcaseDemoView: View {
    @State private var sliderValue: Float = 0.42
    @State private var isSwitchOn = true
    @State private var isLensLifted = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("LiquidGlassKit Showcase")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text("直接使用开源 LiquidGlassKit，不再维护本地复刻")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.78))

                    showcaseCard(title: "Icon Effect", subtitle: "VisualEffectView + LiquidGlassEffect") {
                        HStack(spacing: 14) {
                            LiquidGlassIconView(systemName: "star.fill")
                                .frame(width: 58, height: 58)
                            LiquidGlassIconView(systemName: "paperplane.fill")
                                .frame(width: 58, height: 58)
                            LiquidGlassIconView(systemName: "bookmark.fill")
                                .frame(width: 58, height: 58)
                        }
                    }

                    showcaseCard(title: "Container Merge", subtitle: "LiquidGlassContainerEffect") {
                        LiquidGlassContainerRow(systemNames: ["heart.fill", "tray.full.fill", "arrow.up.circle.fill"])
                            .frame(height: 66)
                    }

                    showcaseCard(title: "Slider", subtitle: "LiquidGlassSlider.make") {
                        VStack(alignment: .leading, spacing: 10) {
                            LiquidGlassSliderRepresentable(value: $sliderValue)
                                .frame(height: 54)

                            Text("Value: \(sliderValue, format: .number.precision(.fractionLength(2)))")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.74))
                        }
                    }

                    showcaseCard(title: "Switch", subtitle: "LiquidGlassSwitch.make") {
                        HStack(spacing: 12) {
                            LiquidGlassSwitchRepresentable(isOn: $isSwitchOn)
                                .frame(width: 74, height: 42)

                            Text(isSwitchOn ? "Enabled" : "Disabled")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                    }

                    showcaseCard(title: "Lens", subtitle: "LiquidLensView") {
                        VStack(alignment: .leading, spacing: 10) {
                            LiquidLensRepresentable(isLifted: isLensLifted)
                                .frame(width: 132, height: 56)

                            Button(isLensLifted ? "Set Resting" : "Set Lifted") {
                                withAnimation(.snappy(duration: 0.24)) {
                                    isLensLifted.toggle()
                                }
                            }
                            .buttonStyle(.plain)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.white.opacity(0.14), in: .capsule)
                        }
                    }
                }
                .padding(20)
                .padding(.top, 6)
            }
            .scrollIndicators(.hidden)
            .background(FlowingBlueBackground())
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private func showcaseCard<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.68))
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08), in: .rect(cornerRadius: 16))
    }
}

private struct LiquidGlassIconView: UIViewRepresentable {
    let systemName: String

    func makeUIView(context: Context) -> UIView {
        let host = UIView()
        host.backgroundColor = .clear

        let glass = VisualEffectView(effect: LiquidGlassEffect(style: .regular, isNative: true))
        glass.layer.cornerRadius = 28
        glass.layer.cornerCurve = .continuous
        glass.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(glass)

        let image = UIImageView(image: UIImage(systemName: systemName))
        image.contentMode = .center
        image.tintColor = .white
        image.preferredSymbolConfiguration = .init(pointSize: 20, weight: .semibold)
        image.translatesAutoresizingMaskIntoConstraints = false
        glass.contentView.addSubview(image)

        NSLayoutConstraint.activate([
            glass.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            glass.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            glass.topAnchor.constraint(equalTo: host.topAnchor),
            glass.bottomAnchor.constraint(equalTo: host.bottomAnchor),
            image.centerXAnchor.constraint(equalTo: glass.contentView.centerXAnchor),
            image.centerYAnchor.constraint(equalTo: glass.contentView.centerYAnchor)
        ])

        return host
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

private struct LiquidGlassContainerRow: UIViewRepresentable {
    let systemNames: [String]

    func makeUIView(context: Context) -> UIView {
        let host = UIView()
        host.backgroundColor = .clear

        let containerEffect = LiquidGlassContainerEffect(isNative: true)
        containerEffect.spacing = 10
        let container = VisualEffectView(effect: containerEffect)
        container.layer.cornerRadius = 32
        container.layer.cornerCurve = .continuous
        container.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(container)

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .fill
        stack.distribution = .fillEqually
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.contentView.addSubview(stack)

        for name in systemNames {
            let iconGlass = VisualEffectView(effect: LiquidGlassEffect(style: .regular, isNative: true))
            iconGlass.layer.cornerRadius = 24
            iconGlass.layer.cornerCurve = .continuous
            iconGlass.translatesAutoresizingMaskIntoConstraints = false

            let image = UIImageView(image: UIImage(systemName: name))
            image.contentMode = .center
            image.tintColor = .white
            image.preferredSymbolConfiguration = .init(pointSize: 18, weight: .semibold)
            image.translatesAutoresizingMaskIntoConstraints = false
            iconGlass.contentView.addSubview(image)

            NSLayoutConstraint.activate([
                image.centerXAnchor.constraint(equalTo: iconGlass.contentView.centerXAnchor),
                image.centerYAnchor.constraint(equalTo: iconGlass.contentView.centerYAnchor),
                iconGlass.heightAnchor.constraint(equalToConstant: 48)
            ])

            stack.addArrangedSubview(iconGlass)
        }

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            container.topAnchor.constraint(equalTo: host.topAnchor),
            container.bottomAnchor.constraint(equalTo: host.bottomAnchor),

            stack.leadingAnchor.constraint(equalTo: container.contentView.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: container.contentView.trailingAnchor, constant: -10),
            stack.topAnchor.constraint(equalTo: container.contentView.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: container.contentView.bottomAnchor, constant: -8)
        ])

        return host
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

private final class SliderHostView: UIView {
    let slider: AnySlider

    init() {
        slider = LiquidGlassSlider.make(isNative: true)
        super.init(frame: .zero)
        backgroundColor = .clear

        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.translatesAutoresizingMaskIntoConstraints = false
        addSubview(slider)

        NSLayoutConstraint.activate([
            slider.leadingAnchor.constraint(equalTo: leadingAnchor),
            slider.trailingAnchor.constraint(equalTo: trailingAnchor),
            slider.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private struct LiquidGlassSliderRepresentable: UIViewRepresentable {
    @Binding var value: Float

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> SliderHostView {
        let host = SliderHostView()
        host.slider.value = value
        host.slider.addTarget(context.coordinator, action: #selector(Coordinator.valueDidChange(_:)), for: .valueChanged)
        return host
    }

    func updateUIView(_ uiView: SliderHostView, context: Context) {
        if abs(uiView.slider.value - value) > 0.0001 {
            uiView.slider.setValue(value, animated: true)
        }
    }

    final class Coordinator: NSObject {
        var parent: LiquidGlassSliderRepresentable

        init(parent: LiquidGlassSliderRepresentable) {
            self.parent = parent
        }

        @objc func valueDidChange(_ sender: UIControl) {
            guard let slider = sender as? (UIControl & AnySlider) else { return }
            parent.value = slider.value
        }
    }
}

private final class SwitchHostView: UIView {
    let switchControl: AnySwitch

    init() {
        switchControl = LiquidGlassSwitch.make(isNative: true)
        super.init(frame: .zero)
        backgroundColor = .clear

        switchControl.translatesAutoresizingMaskIntoConstraints = false
        addSubview(switchControl)

        NSLayoutConstraint.activate([
            switchControl.centerXAnchor.constraint(equalTo: centerXAnchor),
            switchControl.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private struct LiquidGlassSwitchRepresentable: UIViewRepresentable {
    @Binding var isOn: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> SwitchHostView {
        let host = SwitchHostView()
        host.switchControl.setOn(isOn, animated: false)
        host.switchControl.addTarget(context.coordinator, action: #selector(Coordinator.switchDidChange(_:)), for: .valueChanged)
        return host
    }

    func updateUIView(_ uiView: SwitchHostView, context: Context) {
        if uiView.switchControl.isOn != isOn {
            uiView.switchControl.setOn(isOn, animated: true)
        }
    }

    final class Coordinator: NSObject {
        var parent: LiquidGlassSwitchRepresentable

        init(parent: LiquidGlassSwitchRepresentable) {
            self.parent = parent
        }

        @objc func switchDidChange(_ sender: UIControl) {
            guard let switchControl = sender as? (UIControl & AnySwitch) else { return }
            parent.isOn = switchControl.isOn
        }
    }
}

private final class LensHostView: UIView {
    let lensView = LiquidLensView()

    init() {
        super.init(frame: .zero)
        backgroundColor = .clear

        lensView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(lensView)

        let content = UIImageView(image: UIImage(systemName: "sparkles"))
        content.tintColor = .white
        content.contentMode = .center
        lensView.setLiftedContentView(content)

        NSLayoutConstraint.activate([
            lensView.leadingAnchor.constraint(equalTo: leadingAnchor),
            lensView.trailingAnchor.constraint(equalTo: trailingAnchor),
            lensView.topAnchor.constraint(equalTo: topAnchor),
            lensView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private struct LiquidLensRepresentable: UIViewRepresentable {
    var isLifted: Bool

    func makeUIView(context: Context) -> LensHostView {
        let host = LensHostView()
        host.lensView.setLifted(isLifted, animated: false, alongsideAnimations: nil, completion: nil)
        return host
    }

    func updateUIView(_ uiView: LensHostView, context: Context) {
        uiView.lensView.setLifted(isLifted, animated: true, alongsideAnimations: nil, completion: nil)
    }
}

private struct FlowingBlueBackground: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                Color(red: 0.02, green: 0.06, blue: 0.14)

                movingBlob(
                    color: Color(red: 0.10, green: 0.56, blue: 1.00),
                    x: 180 * sin(t * 0.35),
                    y: 120 * cos(t * 0.27),
                    scale: 1.25
                )

                movingBlob(
                    color: Color(red: 0.18, green: 0.78, blue: 1.00),
                    x: -150 * cos(t * 0.31),
                    y: 100 * sin(t * 0.41),
                    scale: 1.05
                )

                movingBlob(
                    color: Color(red: 0.04, green: 0.32, blue: 0.95),
                    x: 130 * sin(t * 0.22 + 1.4),
                    y: -110 * cos(t * 0.18 + 0.9),
                    scale: 1.4
                )
            }
            .overlay {
                LinearGradient(
                    colors: [
                        .black.opacity(0.08),
                        .clear,
                        .black.opacity(0.18)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea()
        }
    }

    private func movingBlob(color: Color, x: CGFloat, y: CGFloat, scale: CGFloat) -> some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [
                        color.opacity(0.70),
                        color.opacity(0.22),
                        .clear
                    ],
                    center: .center,
                    startRadius: 10,
                    endRadius: 340
                )
            )
            .frame(width: 620 * scale, height: 620 * scale)
            .offset(x: x, y: y)
            .blur(radius: 36)
            .blendMode(.screen)
    }
}

#Preview {
    IconShowcaseDemoView()
}
