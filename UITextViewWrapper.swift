//
//  UITextViewWrapper.swift
//  QuickNote
//
//  Created by Yuki Sasaki on 2025/08/25.
//

import SwiftUI

// MARK: - UITextViewWrapper
struct UITextViewWrapper: UIViewRepresentable {
    @Binding var attributedText: NSMutableAttributedString
    var isFirstResponder: Bool = false
    var onCopy: (() -> Void)? // 追加
    
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

        // キーボードの上にツールバーを追加
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let copyButton = UIBarButtonItem(image: UIImage(systemName: "doc.on.doc"), style: .plain, target: context.coordinator, action: #selector(context.coordinator.copyText))
        toolbar.items = [flexibleSpace, copyButton]
        textView.inputAccessoryView = toolbar

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
            // フォント属性を付与
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24)
            ]
            let newAttrText = NSMutableAttributedString(attributedString: attributedText)
            newAttrText.addAttributes(attributes, range: NSRange(location: 0, length: newAttrText.length))
            
            // 差分があれば更新
            if textView.attributedText != newAttrText {
                textView.attributedText = newAttrText
            }
            
            // 最初のフォーカス
            if isFirstResponder && !textView.isFirstResponder {
                textView.becomeFirstResponder()
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
            parent.onCopy?() // ← これでコピー時にトースト表示
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
            return false // デフォルト処理はキャンセル
        }
    }
}


