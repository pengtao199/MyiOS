import SwiftUI
import UIKit

struct TheseusShowcaseDemoView: View {
    @State private var selectedTabIndex = 0
    @State private var sliderValue: CGFloat = 50
    @State private var sliderPositions = 0
    @State private var isSwitchOn = true
    @State private var glassBlur: CGFloat = 1.0
    @State private var glassRefraction: CGFloat = 1.45
    @State private var glassCornerRadius: CGFloat = 22

    private let cardRadius: CGFloat = 18

    private var tabItems: [TheseusTabBarItem] {
        [
            TheseusTabBarItem(icon: UIImage(systemName: "house.fill"), title: "Home"),
            TheseusTabBarItem(icon: UIImage(systemName: "sparkles"), title: "Effects"),
            TheseusTabBarItem(icon: UIImage(systemName: "slider.horizontal.3"), title: "Controls"),
            TheseusTabBarItem(icon: UIImage(systemName: "person.fill"), title: "Profile")
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                titleSection
                tabBarSection
                sliderSection
                switchSection
                glassSection
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(TheseusPageBackground().ignoresSafeArea())
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Theseus Real Showcase")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("TabBar / Slider / Switch / Refraction Glass")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    private var tabBarSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("TheseusTabBar")
            TheseusTabBarRepresentable(items: tabItems, selectedIndex: $selectedTabIndex)
                .frame(height: 62)
            Text("Selected: \(selectedTabIndex)")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.white.opacity(0.7))
        }
        .cardStyle(cornerRadius: cardRadius)
    }

    private var sliderSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("TheseusSlider")
            Text("Value: \(Int(sliderValue))")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.white.opacity(0.86))

            TheseusSliderRepresentable(
                value: $sliderValue,
                minimumValue: 0,
                maximumValue: 100,
                positionsCount: sliderPositions
            )
            .frame(height: 44)

            Picker("Positions", selection: $sliderPositions) {
                Text("Continuous").tag(0)
                Text("5").tag(5)
                Text("10").tag(10)
                Text("20").tag(20)
            }
            .pickerStyle(.segmented)
        }
        .cardStyle(cornerRadius: cardRadius)
    }

    private var switchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("TheseusSwitch")
            HStack {
                Text(isSwitchOn ? "State: ON" : "State: OFF")
                    .font(.subheadline.monospaced())
                    .foregroundStyle(.white.opacity(0.86))
                Spacer()
                TheseusSwitchRepresentable(isOn: $isSwitchOn)
                    .frame(width: 64, height: 30)
            }
        }
        .cardStyle(cornerRadius: cardRadius)
    }

    private var glassSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("TheseusView (Refraction Lens)")
            TheseusGlassShowcaseRepresentable(
                blurRadius: glassBlur,
                refractionIntensity: glassRefraction,
                cornerRadius: glassCornerRadius
            )
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            settingRow(title: "Blur", value: $glassBlur, range: 0...2)
            settingRow(title: "Refraction", value: $glassRefraction, range: 0.8...2.2)
            settingRow(title: "Corner", value: $glassCornerRadius, range: 12...36)
        }
        .cardStyle(cornerRadius: cardRadius)
    }

    private func settingRow(title: String, value: Binding<CGFloat>, range: ClosedRange<CGFloat>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
                Spacer()
                Text(value.wrappedValue, format: .number.precision(.fractionLength(2)))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.65))
            }
            Slider(value: value, in: range)
                .tint(.cyan)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.white)
    }
}

private struct TheseusPageBackground: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.09, blue: 0.18),
                    Color(red: 0.03, green: 0.14, blue: 0.22),
                    Color(red: 0.03, green: 0.06, blue: 0.11)
                ],
                startPoint: animate ? .topLeading : .bottomTrailing,
                endPoint: animate ? .bottomTrailing : .topLeading
            )

            Circle()
                .fill(Color.cyan.opacity(0.22))
                .frame(width: 300, height: 300)
                .blur(radius: 38)
                .offset(x: animate ? -120 : 120, y: animate ? -260 : -120)

            Circle()
                .fill(Color.pink.opacity(0.20))
                .frame(width: 260, height: 260)
                .blur(radius: 42)
                .offset(x: animate ? 150 : -80, y: animate ? 260 : 120)

            Circle()
                .fill(Color.blue.opacity(0.14))
                .frame(width: 220, height: 220)
                .blur(radius: 30)
                .offset(x: animate ? 90 : -140, y: animate ? 10 : -20)
        }
        .animation(.easeInOut(duration: 7.5).repeatForever(autoreverses: true), value: animate)
        .onAppear {
            animate = true
        }
    }
}

private struct DemoCardStyle: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            }
    }
}

private extension View {
    func cardStyle(cornerRadius: CGFloat) -> some View {
        modifier(DemoCardStyle(cornerRadius: cornerRadius))
    }
}

private struct TheseusTabBarRepresentable: UIViewRepresentable {
    let items: [TheseusTabBarItem]
    @Binding var selectedIndex: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> TheseusTabBar {
        let tabBar = TheseusTabBar()
        tabBar.items = items
        tabBar.selectedIndex = selectedIndex
        tabBar.selectedTintColor = .systemBlue
        tabBar.unselectedTintColor = .white
        tabBar.glassBlurRadius = 3.0
        tabBar.glassRefractionFactor = 1.42
        tabBar.onItemSelected = { index in
            context.coordinator.parent.selectedIndex = index
        }
        return tabBar
    }

    func updateUIView(_ uiView: TheseusTabBar, context: Context) {
        if uiView.items.count != items.count {
            uiView.items = items
        }
        uiView.selectedIndex = selectedIndex
    }

    final class Coordinator {
        var parent: TheseusTabBarRepresentable

        init(_ parent: TheseusTabBarRepresentable) {
            self.parent = parent
        }
    }
}

private struct TheseusSliderRepresentable: UIViewRepresentable {
    @Binding var value: CGFloat
    let minimumValue: CGFloat
    let maximumValue: CGFloat
    let positionsCount: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> TheseusSlider {
        let slider = TheseusSlider()
        slider.minimumValue = minimumValue
        slider.maximumValue = maximumValue
        slider.positionsCount = positionsCount
        slider.trackColor = .systemBlue
        slider.setValue(value)
        slider.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        return slider
    }

    func updateUIView(_ uiView: TheseusSlider, context: Context) {
        uiView.minimumValue = minimumValue
        uiView.maximumValue = maximumValue
        uiView.positionsCount = positionsCount
        if !uiView.isTracking {
            uiView.setValue(value)
        }
    }

    final class Coordinator: NSObject {
        var parent: TheseusSliderRepresentable

        init(_ parent: TheseusSliderRepresentable) {
            self.parent = parent
        }

        @objc func valueChanged(_ sender: TheseusSlider) {
            parent.value = sender.value
        }
    }
}

private struct TheseusSwitchRepresentable: UIViewRepresentable {
    @Binding var isOn: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> TheseusSwitch {
        let switchControl = TheseusSwitch()
        switchControl.isOn = isOn
        switchControl.onValueChanged = { newValue in
            context.coordinator.parent.isOn = newValue
        }
        return switchControl
    }

    func updateUIView(_ uiView: TheseusSwitch, context: Context) {
        if uiView.isOn != isOn {
            uiView.setOn(isOn, animated: true)
        }
    }

    final class Coordinator {
        var parent: TheseusSwitchRepresentable

        init(_ parent: TheseusSwitchRepresentable) {
            self.parent = parent
        }
    }
}

private struct TheseusGlassShowcaseRepresentable: UIViewRepresentable {
    var blurRadius: CGFloat
    var refractionIntensity: CGFloat
    var cornerRadius: CGFloat

    func makeUIView(context: Context) -> TheseusGlassShowcaseContainer {
        let view = TheseusGlassShowcaseContainer()
        view.updateConfiguration(
            blurRadius: blurRadius,
            refractionIntensity: refractionIntensity,
            cornerRadius: cornerRadius
        )
        return view
    }

    func updateUIView(_ uiView: TheseusGlassShowcaseContainer, context: Context) {
        uiView.updateConfiguration(
            blurRadius: blurRadius,
            refractionIntensity: refractionIntensity,
            cornerRadius: cornerRadius
        )
    }
}

private final class TheseusGlassShowcaseContainer: UIView {
    private let gradientLayer = CAGradientLayer()
    private let sourceView = UIView()
    private let lensLabel = UILabel()
    private let glassView = TheseusView()
    private var blobViews: [UIView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        sourceView.frame = bounds
        gradientLayer.frame = sourceView.bounds

        if blobViews.isEmpty {
            createBlobs()
        }
        layoutBlobs()

        let lensSize = CGSize(width: min(bounds.width - 24, 220), height: 110)
        glassView.frame = CGRect(
            x: (bounds.width - lensSize.width) * 0.5,
            y: (bounds.height - lensSize.height) * 0.5,
            width: lensSize.width,
            height: lensSize.height
        )
        lensLabel.frame = glassView.bounds
    }

    func updateConfiguration(blurRadius: CGFloat, refractionIntensity: CGFloat, cornerRadius: CGFloat) {
        var configuration = glassView.configuration
        configuration.theme = .light
        configuration.blur.radius = blurRadius
        configuration.refraction.intensity = refractionIntensity
        configuration.refraction.dispersion = 4.0
        configuration.shape.cornerRadius = cornerRadius
        configuration.edgeEffects.glareIntensity = 1.0
        configuration.edgeEffects.rimGlow = 0.6
        glassView.configuration = configuration
        glassView.sourceView = sourceView
    }

    private func setupViews() {
        clipsToBounds = true
        layer.cornerRadius = 14

        gradientLayer.colors = [
            UIColor(red: 0.97, green: 0.82, blue: 0.42, alpha: 1).cgColor,
            UIColor(red: 0.96, green: 0.40, blue: 0.53, alpha: 1).cgColor,
            UIColor(red: 0.39, green: 0.47, blue: 0.96, alpha: 1).cgColor,
            UIColor(red: 0.25, green: 0.73, blue: 0.83, alpha: 1).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        sourceView.layer.addSublayer(gradientLayer)
        addSubview(sourceView)

        glassView.continuousUpdate = true
        addSubview(glassView)

        lensLabel.text = "Refraction Lens"
        lensLabel.textAlignment = .center
        lensLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        lensLabel.textColor = UIColor.white.withAlphaComponent(0.92)
        glassView.addSubview(lensLabel)

        startBackgroundAnimation()
    }

    private func createBlobs() {
        let colors: [UIColor] = [
            .white.withAlphaComponent(0.36),
            .systemPink.withAlphaComponent(0.45),
            .systemBlue.withAlphaComponent(0.42),
            .systemTeal.withAlphaComponent(0.35)
        ]

        blobViews = colors.map { color in
            let view = UIView()
            view.backgroundColor = color
            view.layer.cornerRadius = 100
            view.layer.compositingFilter = "screenBlendMode"
            sourceView.addSubview(view)
            return view
        }

        animateBlobs()
    }

    private func layoutBlobs() {
        guard blobViews.count == 4 else { return }
        let w = bounds.width
        let h = bounds.height
        blobViews[0].frame = CGRect(x: 20, y: 18, width: 110, height: 110)
        blobViews[1].frame = CGRect(x: w - 140, y: 12, width: 120, height: 120)
        blobViews[2].frame = CGRect(x: 28, y: h - 110, width: 90, height: 90)
        blobViews[3].frame = CGRect(x: w - 110, y: h - 95, width: 86, height: 86)
    }

    private func startBackgroundAnimation() {
        let startAnimation = CABasicAnimation(keyPath: "startPoint")
        startAnimation.fromValue = CGPoint(x: 0, y: 0)
        startAnimation.toValue = CGPoint(x: 1, y: 0)

        let endAnimation = CABasicAnimation(keyPath: "endPoint")
        endAnimation.fromValue = CGPoint(x: 1, y: 1)
        endAnimation.toValue = CGPoint(x: 0, y: 1)

        let colorAnimation = CAKeyframeAnimation(keyPath: "colors")
        colorAnimation.values = [
            [
                UIColor(red: 0.97, green: 0.82, blue: 0.42, alpha: 1).cgColor,
                UIColor(red: 0.96, green: 0.40, blue: 0.53, alpha: 1).cgColor,
                UIColor(red: 0.39, green: 0.47, blue: 0.96, alpha: 1).cgColor,
                UIColor(red: 0.25, green: 0.73, blue: 0.83, alpha: 1).cgColor
            ],
            [
                UIColor(red: 0.44, green: 0.79, blue: 0.98, alpha: 1).cgColor,
                UIColor(red: 0.38, green: 0.55, blue: 0.97, alpha: 1).cgColor,
                UIColor(red: 0.86, green: 0.47, blue: 0.86, alpha: 1).cgColor,
                UIColor(red: 0.97, green: 0.66, blue: 0.45, alpha: 1).cgColor
            ],
            [
                UIColor(red: 0.97, green: 0.82, blue: 0.42, alpha: 1).cgColor,
                UIColor(red: 0.96, green: 0.40, blue: 0.53, alpha: 1).cgColor,
                UIColor(red: 0.39, green: 0.47, blue: 0.96, alpha: 1).cgColor,
                UIColor(red: 0.25, green: 0.73, blue: 0.83, alpha: 1).cgColor
            ]
        ]
        colorAnimation.keyTimes = [0.0, 0.5, 1.0]

        let group = CAAnimationGroup()
        group.animations = [startAnimation, endAnimation, colorAnimation]
        group.duration = 9.0
        group.autoreverses = true
        group.repeatCount = .infinity
        group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        gradientLayer.add(group, forKey: "movingGradient")
    }

    private func animateBlobs() {
        for (index, blob) in blobViews.enumerated() {
            let drift = CAKeyframeAnimation(keyPath: "transform.translation")
            drift.values = [
                CGPoint.zero,
                CGPoint(x: index % 2 == 0 ? 14 : -14, y: index < 2 ? 10 : -10),
                CGPoint(x: index % 2 == 0 ? -12 : 12, y: index < 2 ? -8 : 8),
                CGPoint.zero
            ]
            drift.keyTimes = [0.0, 0.35, 0.7, 1.0]

            let scale = CAKeyframeAnimation(keyPath: "transform.scale")
            scale.values = [1.0, 1.08, 0.95, 1.0]
            scale.keyTimes = [0.0, 0.35, 0.7, 1.0]

            let group = CAAnimationGroup()
            group.animations = [drift, scale]
            group.duration = 4.8 + Double(index) * 0.6
            group.repeatCount = .infinity
            group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            blob.layer.add(group, forKey: "blobMotion\(index)")
        }
    }
}

#Preview {
    TheseusShowcaseDemoView()
}
