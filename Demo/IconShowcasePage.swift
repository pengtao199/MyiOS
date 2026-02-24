//
//  IconShowcasePage.swift
//  Demo
//
//  Created by Codex on 2026/2/24.
//

import SwiftUI

struct IconShowcasePage: View {
    private let items: [IconItem] = [
        .init(systemName: "square.and.arrow.up", label: "Share"),
        .init(systemName: "bookmark.fill", label: "Save"),
        .init(systemName: "heart.fill", label: "Like")
    ]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 28) {
                Text("iOS 26 Official")
                    .font(.headline)
                    .foregroundStyle(.white)
                IconSingleOfficial(item: items[0])
                IconRowOfficial(items: items)

                Text("Handcrafted Replica")
                    .font(.headline)
                    .foregroundStyle(.white)
                IconSingleReplica(item: items[0])
                IconRowReplica(items: items)

                Text("LiquidGlassKit (Open Source)")
                    .font(.headline)
                    .foregroundStyle(.white)
                LiquidGlassKitSingleIcon(systemName: items[0].systemName)
                    .frame(width: 56, height: 56)
                LiquidGlassKitIconRow(systemNames: items.map(\.systemName))
                    .frame(width: 188, height: 64)

                Spacer()
            }
            .padding(20)
            .navigationTitle("Icon Compare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .background(FlowingBlueBackground())
        }
    }
}

struct IconItem: Identifiable {
    let id = UUID()
    let systemName: String
    let label: String
}

struct IconRowOfficial: View {
    let items: [IconItem]

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 2) {
                    ForEach(items) { item in
                        Button {
                            print("\(item.label) tapped")
                        } label: {
                            Image(systemName: item.systemName)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .glassEffect(.regular.interactive(), in: .capsule)
            }
        } else {
            HStack(spacing: 2) {
                ForEach(items) { item in
                    Button {
                        print("\(item.label) tapped")
                    } label: {
                        Image(systemName: item.systemName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }
}

struct IconRowReplica: View {
    let items: [IconItem]
    @State private var capsuleScale: CGFloat = 1
    @State private var isAnimatingBounce = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items) { item in
                Button {
                    print("\(item.label) tapped")
                } label: {
                    Image(systemName: item.systemName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .contentShape(.capsule)
        .background {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.22),
                            .white.opacity(0.08),
                            .white.opacity(0.14)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                )
                .overlay {
                    Capsule()
                        .strokeBorder(.white.opacity(0.34), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 6)
        }
        .scaleEffect(capsuleScale)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    runBounceIfNeeded()
                }
                .onEnded { _ in
                    if !isAnimatingBounce {
                        runBounceIfNeeded()
                    }
                }
        )
    }

    private func runBounceIfNeeded() {
        guard !isAnimatingBounce else { return }
        isAnimatingBounce = true
        withAnimation(.spring(response: 0.12, dampingFraction: 0.8)) {
            capsuleScale = 1.08
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
            withAnimation(.spring(response: 0.14, dampingFraction: 0.62)) {
                capsuleScale = 0.9
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                capsuleScale = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                isAnimatingBounce = false
            }
        }
    }
}

struct IconSingleOfficial: View {
    let item: IconItem

    var body: some View {
        if #available(iOS 26.0, *) {
            Button {
                print("\(item.label) tapped")
            } label: {
                Image(systemName: item.systemName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
        } else {
            Button {
                print("\(item.label) tapped")
            } label: {
                Image(systemName: item.systemName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
            }
            .buttonStyle(.plain)
        }
    }
}

struct IconSingleReplica: View {
    let item: IconItem
    @State private var circleScale: CGFloat = 1
    @State private var isAnimatingBounce = false

    var body: some View {
        Button {
            print("\(item.label) tapped")
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.22),
                                .white.opacity(0.08),
                                .white.opacity(0.14)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
                    .overlay {
                        Circle()
                            .strokeBorder(.white.opacity(0.34), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 6)

                Image(systemName: item.systemName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 56, height: 56)
        }
        .buttonStyle(.plain)
        .contentShape(.circle)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    runBounceIfNeeded()
                }
                .onEnded { _ in
                    if !isAnimatingBounce {
                        runBounceIfNeeded()
                    }
                }
        )
        .scaleEffect(circleScale)
    }

    private func runBounceIfNeeded() {
        guard !isAnimatingBounce else { return }
        isAnimatingBounce = true
        withAnimation(.spring(response: 0.12, dampingFraction: 0.8)) {
            circleScale = 1.08
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
            withAnimation(.spring(response: 0.14, dampingFraction: 0.62)) {
                circleScale = 0.9
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                circleScale = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                isAnimatingBounce = false
            }
        }
    }
}

struct LiquidGlassKitSingleIcon: UIViewRepresentable {
    let systemName: String

    func makeUIView(context: Context) -> UIView {
        let host = UIView()
        host.backgroundColor = .clear

        let effectView = VisualEffectView(effect: LiquidGlassEffect(style: .regular, isNative: false))
        effectView.contentView.backgroundColor = .clear
        effectView.layer.cornerRadius = 27
        effectView.layer.cornerCurve = .continuous
        effectView.clipsToBounds = false
        effectView.contentView.layer.cornerRadius = 27
        effectView.contentView.layer.cornerCurve = .continuous
        effectView.contentView.layer.masksToBounds = true
        effectView.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(effectView)

        let icon = UIImageView(image: UIImage(systemName: systemName))
        icon.tintColor = .white
        icon.preferredSymbolConfiguration = .init(pointSize: 20, weight: .semibold)
        icon.translatesAutoresizingMaskIntoConstraints = false
        effectView.contentView.addSubview(icon)

        NSLayoutConstraint.activate([
            effectView.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: 1),
            effectView.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -1),
            effectView.topAnchor.constraint(equalTo: host.topAnchor, constant: 1),
            effectView.bottomAnchor.constraint(equalTo: host.bottomAnchor, constant: -1),
            icon.centerXAnchor.constraint(equalTo: effectView.contentView.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: effectView.contentView.centerYAnchor)
        ])
        return host
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct LiquidGlassKitIconRow: UIViewRepresentable {
    let systemNames: [String]

    func makeUIView(context: Context) -> UIView {
        let host = UIView()
        host.backgroundColor = .clear

        let capsule = VisualEffectView(effect: LiquidGlassEffect(style: .regular, isNative: false))
        capsule.contentView.backgroundColor = .clear
        capsule.layer.cornerRadius = 30
        capsule.layer.cornerCurve = .continuous
        capsule.clipsToBounds = false
        capsule.contentView.layer.cornerRadius = 30
        capsule.contentView.layer.cornerCurve = .continuous
        capsule.contentView.layer.masksToBounds = true
        capsule.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(capsule)

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .fillEqually
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        capsule.contentView.addSubview(stack)

        for name in systemNames {
            let icon = UIImageView(image: UIImage(systemName: name))
            icon.tintColor = .white
            icon.preferredSymbolConfiguration = .init(pointSize: 20, weight: .semibold)
            icon.contentMode = .center
            icon.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                icon.widthAnchor.constraint(equalToConstant: 56),
                icon.heightAnchor.constraint(equalToConstant: 56)
            ])

            stack.addArrangedSubview(icon)
        }

        NSLayoutConstraint.activate([
            capsule.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            capsule.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            capsule.topAnchor.constraint(equalTo: host.topAnchor, constant: 2),
            capsule.bottomAnchor.constraint(equalTo: host.bottomAnchor, constant: -2),

            stack.leadingAnchor.constraint(equalTo: capsule.contentView.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: capsule.contentView.trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: capsule.contentView.topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: capsule.contentView.bottomAnchor, constant: -4)
        ])

        return host
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct FlowingBlueBackground: View {
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
    IconShowcasePage()
}
