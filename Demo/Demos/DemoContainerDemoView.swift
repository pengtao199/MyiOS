//
//  DemoContainerDemoView.swift
//  Demo
//
//  Created by Codex on 2026/2/25.
//

import SwiftUI

private enum DemoEntry: String, CaseIterable, Identifiable {
    case iconShowcase
    case cardSwipe
    case legacyClock

    var id: String { rawValue }

    var title: String {
        switch self {
        case .iconShowcase:
            "Icon Showcase"
        case .cardSwipe:
            "Card Swipe"
        case .legacyClock:
            "Legacy Clock"
        }
    }

    var accent: Color {
        switch self {
        case .iconShowcase:
            .cyan
        case .cardSwipe:
            .orange
        case .legacyClock:
            .mint
        }
    }

    @ViewBuilder
    var destinationView: some View {
        switch self {
        case .iconShowcase:
            IconShowcaseDemoView()
        case .cardSwipe:
            CardSwipeDemoView()
        case .legacyClock:
            LegacyClockDemoView()
        }
    }
}

struct DemoContainerDemoView: View {
    @State private var showMenu = false
    @State private var selectedEntry: DemoEntry?

    var body: some View {
        AnimatedMenuContainer(
            rotatesWhenExpands: true,
            disablesInteraction: true,
            sideMenuWidth: 280,
            cornerRadius: 24,
            showMenu: $showMenu
        ) { safeArea in
            ZStack(alignment: .topLeading) {
                Group {
                    if let selectedEntry {
                        selectedEntry.destinationView
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .ignoresSafeArea(.container, edges: [.top, .bottom])
                            .transition(.opacity)
                    } else {
                        homeGuideView
                            .transition(.opacity)
                    }
                }

                topMenuButton(safeArea: safeArea)
            }
        } menuView: { safeArea in
            sidebarView(safeArea: safeArea)
        } background: {
            LinearGradient(
                colors: [.black, Color(red: 0.05, green: 0.08, blue: 0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var homeGuideView: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("Demo Container")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("左滑打开菜单，点击标题直接切换 Demo")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.78))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    private func topMenuButton(safeArea: EdgeInsets) -> some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.snappy(duration: 0.28)) {
                    showMenu.toggle()
                }
            } label: {
                Image(systemName: showMenu ? "xmark" : "line.3.horizontal")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.35), in: .circle)
            }

            Text(selectedEntry?.title ?? "Home")
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(.top, safeArea.top + 8)
        .padding(.horizontal, 14)
    }

    private func sidebarView(safeArea: EdgeInsets) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Demos")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .padding(.bottom, 8)

            ForEach(DemoEntry.allCases) { entry in
                Button {
                    withAnimation(.snappy(duration: 0.24)) {
                        selectedEntry = entry
                        showMenu = false
                    }
                } label: {
                    HStack {
                        Text(entry.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                    .background(
                        (selectedEntry == entry ? entry.accent.opacity(0.34) : .white.opacity(0.10)),
                        in: .rect(cornerRadius: 12)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, safeArea.top + 8)
        .padding(.bottom, safeArea.bottom + 8)
    }
}

private struct AnimatedMenuContainer<Content: View, MenuView: View, Background: View>: View {
    let rotatesWhenExpands: Bool
    let disablesInteraction: Bool
    let sideMenuWidth: CGFloat
    let cornerRadius: CGFloat
    @Binding var showMenu: Bool
    @ViewBuilder var content: (EdgeInsets) -> Content
    @ViewBuilder var menuView: (EdgeInsets) -> MenuView
    @ViewBuilder var background: Background

    @GestureState private var isDragging = false
    @State private var offsetX: CGFloat = 0
    @State private var lastOffsetX: CGFloat = 0
    @State private var progress: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let safeArea = proxy.safeAreaInsets

            HStack(spacing: 0) {
                menuView(safeArea)
                    .frame(width: sideMenuWidth, height: size.height)
                    .contentShape(.rect)

                content(safeArea)
                    .frame(width: size.width, height: size.height)
                    .overlay {
                        if disablesInteraction && progress > 0 {
                            Rectangle()
                                .fill(.black.opacity(progress * 0.22))
                                .onTapGesture {
                                    withAnimation(.snappy(duration: 0.28)) {
                                        closeMenu()
                                    }
                                }
                        }
                    }
                    .mask {
                        RoundedRectangle(cornerRadius: progress * cornerRadius)
                    }
                    .scaleEffect(rotatesWhenExpands ? (1 - progress * 0.1) : 1, anchor: .trailing)
                    .rotation3DEffect(
                        .degrees(rotatesWhenExpands ? (progress * -15) : 0),
                        axis: (x: 0, y: 1, z: 0)
                    )
            }
            .frame(width: sideMenuWidth + size.width, height: size.height)
            .offset(x: -sideMenuWidth)
            .offset(x: offsetX)
            .clipped()
            .contentShape(.rect)
            .simultaneousGesture(dragGesture)
        }
        .background(background)
        .ignoresSafeArea()
        .onChange(of: showMenu, initial: true) { _, newValue in
            withAnimation(.snappy(duration: 0.28)) {
                if newValue {
                    openMenu()
                } else {
                    closeMenu()
                }
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .updating($isDragging) { _, out, _ in
                out = true
            }
            .onChanged { value in
                if !showMenu && value.startLocation.x > 30 {
                    return
                }
                let translationX = isDragging ? max(min(value.translation.width + lastOffsetX, sideMenuWidth), 0) : 0
                offsetX = translationX
                updateProgress()
            }
            .onEnded { value in
                if !showMenu && value.startLocation.x > 30 {
                    return
                }
                withAnimation(.snappy(duration: 0.28)) {
                    let velocityX = value.velocity.width / 8
                    let total = velocityX + offsetX
                    if total > (sideMenuWidth * 0.5) {
                        openMenu()
                    } else {
                        closeMenu()
                    }
                }
            }
    }

    private func openMenu() {
        offsetX = sideMenuWidth
        lastOffsetX = offsetX
        showMenu = true
        updateProgress()
    }

    private func closeMenu() {
        offsetX = 0
        lastOffsetX = 0
        showMenu = false
        updateProgress()
    }

    private func updateProgress() {
        progress = max(min(offsetX / sideMenuWidth, 1), 0)
    }
}

#Preview {
    DemoContainerDemoView()
}
