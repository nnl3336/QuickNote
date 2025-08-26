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

// MARK: - UITextViewWrapper
struct UITextViewWrapper: UIViewRepresentable {
    @Binding var attributedText: NSMutableAttributedString
    var onCopy: (() -> Void)? // コピー時トースト用

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.dataDetectorTypes = [.link]
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.delegate = context.coordinator
        textView.linkTextAttributes = [
            .foregroundColor: UIColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        textView.backgroundColor = .clear

        // キーボード上のツールバー
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let copyButton = UIBarButtonItem(
            image: UIImage(systemName: "doc.on.doc"),
            style: .plain,
            target: context.coordinator,
            action: #selector(context.coordinator.copyText)
        )
        toolbar.items = [flexibleSpace, copyButton]
        textView.inputAccessoryView = toolbar

        textView.keyboardDismissMode = .onDrag

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        // 常にフォント属性を適用
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 20)
        ]
        let newAttrText = NSMutableAttributedString(attributedString: attributedText)
        newAttrText.addAttributes(attributes, range: NSRange(location: 0, length: newAttrText.length))

        // 差分があれば更新
        if textView.attributedText != newAttrText {
            textView.attributedText = newAttrText
        }

        // キーボードを上げたい場合は必ず DispatchQueue.main.async で遅延
        if attributedText.length == 0, !textView.isFirstResponder {
            DispatchQueue.main.async {
                textView.becomeFirstResponder()
            }
        }
    }
    

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: UITextViewWrapper
        init(_ parent: UITextViewWrapper) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            parent.attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
        }

        @objc func copyText() {
            UIPasteboard.general.string = parent.attributedText.string
            parent.onCopy?() // トースト呼び出し
        }
        
        static func dismantleUIView(_ uiView: UITextView, coordinator: Coordinator) {
            uiView.resignFirstResponder()  // **キーボードを閉じる**
        }

        func textView(_ textView: UITextView,
                      shouldInteractWith URL: URL,
                      in characterRange: NSRange,
                      interaction: UITextItemInteraction) -> Bool {
            // http または https のリンクのみ開く
            if URL.absoluteString.lowercased().hasPrefix("http://") ||
               URL.absoluteString.lowercased().hasPrefix("https://") {
                UIApplication.shared.open(URL)
            }
            return false // デフォルト処理をキャンセル
        }
    }
}
