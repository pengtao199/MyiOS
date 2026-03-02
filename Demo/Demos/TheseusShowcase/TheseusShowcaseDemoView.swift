import SwiftUI
import UIKit

struct TheseusShowcaseDemoView: View {
    @State private var selectedTabIndex = 0
    @State private var sliderValue: CGFloat = 50
    @State private var sliderPositions = 0
    @State private var isSwitchOn = true

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
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .safeAreaPadding(.top, 6)
        .background(TheseusPageBackground().ignoresSafeArea())
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Theseus Real Showcase")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("TabBar / Slider / Switch / Direct Lens")
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
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("TheseusView (Direct Lens)")
            Text("直接展示镜片，不使用大容器背景。镜片折射页面实时背景。")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.72))
            TheseusDirectLensRepresentable()
                .frame(height: 136)
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

private struct TheseusDirectLensRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> TheseusDirectLensContainer {
        TheseusDirectLensContainer()
    }

    func updateUIView(_ uiView: TheseusDirectLensContainer, context: Context) {}
}

private final class TheseusDirectLensContainer: UIView {
    private let lensLabel = UILabel()
    private let glassView = TheseusView()

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
        let lensSize = CGSize(width: min(bounds.width - 12, 260), height: 112)
        glassView.frame = CGRect(
            x: (bounds.width - lensSize.width) * 0.5,
            y: (bounds.height - lensSize.height) * 0.5,
            width: lensSize.width,
            height: lensSize.height
        )
        glassView.shape.cornerRadius = lensSize.height / 2
        lensLabel.frame = glassView.bounds
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let sourceView = window?.rootViewController?.view {
            glassView.sourceView = sourceView
            glassView.invalidateBackground()
        }
    }

    private func setupViews() {
        backgroundColor = .clear

        var configuration = glassView.configuration
        configuration.theme = .light
        configuration.blur.radius = 1.05
        configuration.refraction.intensity = 1.45
        configuration.refraction.dispersion = 4.0
        configuration.shape.cornerRadius = 56
        configuration.edgeEffects.glareIntensity = 1.0
        configuration.edgeEffects.rimGlow = 0.6
        glassView.configuration = configuration
        glassView.continuousUpdate = true
        addSubview(glassView)

        lensLabel.text = "Theseus Lens"
        lensLabel.textAlignment = .center
        lensLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        lensLabel.textColor = UIColor.white.withAlphaComponent(0.92)
        glassView.addSubview(lensLabel)
    }
}

#Preview {
    TheseusShowcaseDemoView()
}
