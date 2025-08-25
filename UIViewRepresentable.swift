//
//  UIViewRepresentable.swift
//  QuickNote
//
//  Created by Yuki Sasaki on 2025/08/26.
//

import SwiftUI

struct ScrollableList<Content: View>: UIViewRepresentable {
    let content: Content
    @Binding var isKeyboardVisible: Bool
    
    init(isKeyboardVisible: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self._isKeyboardVisible = isKeyboardVisible
        self.content = content()
    }
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        let hosting = UIHostingController(rootView: content)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(hosting.view)
        
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: scrollView.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            hosting.view.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        return scrollView
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(isKeyboardVisible: $isKeyboardVisible)
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        @Binding var isKeyboardVisible: Bool
        
        init(isKeyboardVisible: Binding<Bool>) {
            self._isKeyboardVisible = isKeyboardVisible
        }
        
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            // スクロール開始でキーボード閉じる
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            isKeyboardVisible = false
        }
    }
}
