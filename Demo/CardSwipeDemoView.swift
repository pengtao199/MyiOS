//
//  CardSwipeDemoView.swift
//  Demo
//
//  Created by mac on 2026/2/23.
//

import SwiftUI

struct SwipeableCard<Content: View>: View {
    let content: Content
    let editAction: () -> Void
    let deleteAction: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var isSwiped: Bool = false
    
    let buttonWidth: CGFloat = 80
    
    init(@ViewBuilder content: () -> Content, editAction: @escaping () -> Void, deleteAction: @escaping () -> Void) {
        self.content = content()
        self.editAction = editAction
        self.deleteAction = deleteAction
    }
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // 底部的按钮组 (固定不动，由滑动内容来遮挡和显露)
            HStack(spacing: 0) {
                Button(action: {
                    withAnimation(.spring()) {
                        offset = 0
                        isSwiped = false
                    }
                    editAction()
                }) {
                    ZStack {
                        Color.blue
                        Text("编辑")
                            .foregroundColor(.white)
                            .fontWeight(.medium)
                    }
                }
                .frame(width: buttonWidth)
                
                Button(action: {
                    withAnimation(.spring()) {
                        offset = 0
                        isSwiped = false
                    }
                    deleteAction()
                }) {
                    ZStack {
                        Color.red
                        Text("删除")
                            .foregroundColor(.white)
                            .fontWeight(.medium)
                    }
                }
                .frame(width: buttonWidth)
            }
            .frame(width: buttonWidth * 2)
            
            // 顶层内容 (跟随手势滑动)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let translation = value.translation.width
                            if !isSwiped {
                                if translation < 0 { // 向左划
                                    // 阻尼效果：不允许无限向左，只允许划出按钮总宽
                                    offset = max(translation, -(buttonWidth * 2))
                                } else {
                                    offset = 0
                                }
                            } else {
                                if translation > 0 { // 向右划回
                                    offset = min(translation - (buttonWidth * 2), 0)
                                } else {
                                    offset = -(buttonWidth * 2)
                                }
                            }
                        }
                        .onEnded { value in
                            let translation = value.translation.width
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if !isSwiped { // 最开始的状态
                                    // 滑动超过阈值则展开
                                    if translation < -40 {
                                        offset = -(buttonWidth * 2)
                                        isSwiped = true
                                    } else {
                                        offset = 0
                                    }
                                } else { // 已经是展开状态
                                    // 向右滑回超过阈值则收起
                                    if translation > 40 {
                                        offset = 0
                                        isSwiped = false
                                    } else {
                                        offset = -(buttonWidth * 2)
                                    }
                                }
                            }
                        }
                )
        }
        // 最关键的一步：对整个容器进行圆角裁剪，内部交接处依然是直角
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .background(
            // 为了保持剪裁后的容器还有漂亮的阴影，将阴影加在这个跟随的背景上
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
}

struct CardSwipeDemoView: View {
    @State private var items = ["苹果", "香蕉", "橘子", "西瓜"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(items, id: \.self) { item in
                        SwipeableCard(
                            content: {
                                HStack {
                                    Image(systemName: "applescript")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 40, height: 40)
                                        .foregroundColor(.orange)
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("项目内容: \(item)")
                                            .font(.headline)
                                        Text("这是默认展示的一些描述信息。")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                }
                                .padding(20)
                            },
                            editAction: {
                                print("点击编辑了: \(item)")
                            },
                            deleteAction: {
                                if let index = items.firstIndex(of: item) {
                                    withAnimation {
                                        items.remove(at: index)
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Card Swipe Demo")
        }
    }
}

#Preview {
    CardSwipeDemoView()
}
