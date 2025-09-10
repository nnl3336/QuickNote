//
//  UITextView.swift
//  QuickNote
//
//  Created by Yuki Sasaki on 2025/08/28.
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers


// MARK: - UITextView
class NoteEditorViewController: UIViewController, UITextViewDelegate {

    var viewContext: NSManagedObjectContext!
    var note: Note?    // 編集対象ノート（nilなら新規）
    
    // ← これを追加
    var onSave: (() -> Void)?
    
    private var textView: UITextView!
    private var toastLabel: UILabel?
    private var didSave = false
    
    private var dateLabel: UILabel!

    //***
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        // 新規作成の場合は Note を生成
        if note == nil {
            let newNote = Note(context: viewContext)
            newNote.id = UUID()
            newNote.date = Date()
            self.note = newNote
        }
        
        setupDateLabel()    // 先にラベルを作る
        setupTextView()     // textView はここで1回だけ作る
        setupNavigationItems()
        
        //ロード
        loadContent() 
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }

    //***
    
    
    private func updateDateLabel() {
        if let date = note?.date {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            dateLabel.text = "作成日: \(formatter.string(from: date))"
        } else {
            dateLabel.text = ""
        }
    }

    
    private func setupDateLabel() {
        dateLabel = UILabel()
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.font = UIFont.systemFont(ofSize: 14)
        dateLabel.textColor = .secondaryLabel
        dateLabel.textAlignment = .center
        
        view.addSubview(dateLabel)
        
        NSLayoutConstraint.activate([
            dateLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            dateLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            dateLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            dateLabel.heightAnchor.constraint(equalToConstant: 20)
        ])
    }


    @objc func appWillResignActive() {
        saveNote()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        textView.resignFirstResponder()
        
        // ナビゲーションで戻るときだけ保存
        if self.isMovingFromParent {
            saveNote()
        }
        
        //view.endEditing(true)   // ← これでキーボードを閉じる
        
    }
    
    private func setupTextView() {
        textView = UITextView(frame: .zero)
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.font = UIFont.systemFont(ofSize: 20)
        textView.delegate = self
        textView.keyboardDismissMode = .interactive
        textView.alwaysBounceVertical = true
        
        // 編集・選択・リンク
        textView.isEditable = true                  // 編集可能
        textView.isSelectable = true                // 選択可能
        textView.dataDetectorTypes = [.link]        // リンク有効
        textView.allowsEditingTextAttributes = true
        textView.isScrollEnabled = true

        
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 200, right: 8) //下に余白

        // キーボード上にツールバー
        textView.inputAccessoryView = createToolbar()
        
        view.addSubview(textView)
        
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            textView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
            textView.bottomAnchor.constraint(equalTo: dateLabel.topAnchor, constant: -8)
        ])

        
        loadContent()
        
        // 新規ノートならキーボードを出す
        /*if note == nil {
            textView.becomeFirstResponder()
        }*/
    }
    
    //***
    
    
    
    private func applyLinkAttributes(to textView: UITextView) {
        // 変換中はスキップ
        guard textView.markedTextRange == nil else { return }

        let text = textView.text ?? ""
        let attr = NSMutableAttributedString(string: text)
        let normalColor = UIColor.label
        let linkColor = UIColor.systemBlue
        let font = UIFont.systemFont(ofSize: 20)

        attr.addAttribute(.font, value: font, range: NSRange(location: 0, length: attr.length))
        attr.addAttribute(.foregroundColor, value: normalColor, range: NSRange(location: 0, length: attr.length))

        // URL 検出
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            detector.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: text.count)) { match, _, _ in
                if let url = match?.url, let range = match?.range {
                    attr.addAttribute(.link, value: url, range: range)
                    attr.addAttribute(.foregroundColor, value: linkColor, range: range)
                }
            }
        }

        let selectedRange = textView.selectedRange
        textView.attributedText = attr
        textView.selectedRange = selectedRange
    }

    
    @objc private func textViewDidChangeNotification(_ notification: Notification) {
        guard let textView = notification.object as? UITextView else { return }
        
        // 変換中は無視
        if textView.markedTextRange != nil { return }
        
        // 最後の操作がペーストかどうか判定
        if UIPasteboard.general.hasStrings {
            applyLinkAttributes(to: textView)
        }
    }
    
    private func applyLinkAttributesToPastedText() {
        let text = textView.text ?? ""
        let attr = NSMutableAttributedString(string: text)
        let normalColor = UIColor.label
        let linkColor = UIColor.systemBlue
        let font = UIFont.systemFont(ofSize: 20)
        
        attr.addAttribute(.font, value: font, range: NSRange(location: 0, length: attr.length))
        attr.addAttribute(.foregroundColor, value: normalColor, range: NSRange(location: 0, length: attr.length))
        
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            detector.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: text.count)) { match, _, _ in
                if let url = match?.url, let range = match?.range {
                    attr.addAttribute(.link, value: url, range: range)
                    attr.addAttribute(.foregroundColor, value: linkColor, range: range)
                }
            }
        }
        
        let selectedRange = textView.selectedRange
        textView.attributedText = attr
        textView.selectedRange = selectedRange
    }

    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(paste(_:)) {
            DispatchQueue.main.async {
                self.applyLinkAttributesToPastedText()
            }
        }
        return super.canPerformAction(action, withSender: sender)
    }





    /// 入力テキスト中の URL を検出して NSMutableAttributedString にリンク属性を付与する
    func attributedStringByDetectingLinks(in text: String, font: UIFont, textColor: UIColor, linkColor: UIColor) -> NSMutableAttributedString {
        let attributedText = NSMutableAttributedString(string: text)
        
        // 全体のフォントと文字色を設定
        attributedText.addAttribute(.font, value: font, range: NSRange(location: 0, length: attributedText.length))
        attributedText.addAttribute(.foregroundColor, value: textColor, range: NSRange(location: 0, length: attributedText.length))
        
        // URL 検出
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            detector.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: text.count)) { match, _, _ in
                if let url = match?.url, let range = match?.range {
                    attributedText.addAttribute(.link, value: url, range: range)
                    attributedText.addAttribute(.foregroundColor, value: linkColor, range: range)
                }
            }
        }
        
        return attributedText
    }

    
    private func createToolbar() -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        
        let copyImage = UIImage(systemName: "doc.on.doc")
        let copyButton = UIBarButtonItem(image: copyImage, style: .plain, target: self, action: #selector(copyText))
        
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        toolbar.items = [flexibleSpace, copyButton, flexibleSpace]
        
        return toolbar
    }


    @objc func copyText() {
        guard let attributed = textView.attributedText else { return }
        let pasteboard = UIPasteboard.general
        pasteboard.items = [[
            UTType.plainText.identifier: attributed.string,
            UTType.rtf.identifier: try! attributed.data(from: NSRange(location: 0, length: attributed.length),
                                                       documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        ]]
        showCopyToast()
    }


    
    private func setupNavigationItems() {
        navigationItem.title = note?.content?.isEmpty ?? true ? "新しいメモ" : "メモを編集"
        
        // 左上の自動「戻るボタン」を使用するので leftBarButtonItem は不要
        
        // 右上に保存ボタン
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "保存",
            style: .done,
            target: self,
            action: #selector(saveTapped)
        )
    }
    
    private func loadContent() {
        let normalColor = UIColor.label        // システム文字色（ライト/ダーク対応）
        let linkColor = UIColor.systemBlue     // リンク色
        let font = UIFont.systemFont(ofSize: 20) // フォントサイズ 20

        // RTFD データがある場合
        if let data = note?.attributedContent,
           let attr = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtfd],
                documentAttributes: nil
           ) as? NSMutableAttributedString {

            let linkedAttr = NSMutableAttributedString.withLinkDetection(from: attr)
            
            // 全体の文字色とフォントを設定
            linkedAttr.addAttribute(.foregroundColor, value: normalColor, range: NSRange(location: 0, length: linkedAttr.length))
            linkedAttr.addAttribute(.font, value: font, range: NSRange(location: 0, length: linkedAttr.length))
            
            // リンク部分だけ色を青に
            linkedAttr.enumerateAttribute(.link, in: NSRange(location: 0, length: linkedAttr.length)) { value, range, _ in
                if value != nil {
                    linkedAttr.addAttribute(.foregroundColor, value: linkColor, range: range)
                }
            }
            
            textView.attributedText = linkedAttr
            
        }
        // プレーンテキストの場合
        else if let content = note?.content {
            let attr = NSMutableAttributedString(string: content)
            let linkedAttr = NSMutableAttributedString.withLinkDetection(from: attr)
            
            linkedAttr.addAttribute(.foregroundColor, value: normalColor, range: NSRange(location: 0, length: linkedAttr.length))
            linkedAttr.addAttribute(.font, value: font, range: NSRange(location: 0, length: linkedAttr.length))
            
            linkedAttr.enumerateAttribute(.link, in: NSRange(location: 0, length: linkedAttr.length)) { value, range, _ in
                if value != nil {
                    linkedAttr.addAttribute(.foregroundColor, value: linkColor, range: range)
                }
            }
            
            textView.attributedText = linkedAttr
        }
        // データなしの場合
        else {
            textView.text = ""
            textView.font = font
            textView.textColor = normalColor
            textView.becomeFirstResponder() // これでキーボードが表示される
        }
        
        updateDateLabel()
    }

    
    
    @objc private func saveTapped() {
        view.endEditing(true)  // キーボードを閉じる
        saveNote()
        //showSaveToast()        // ← 保存完了トーストを表示
        //navigationController?.popViewController(animated: true)
        Toast.showToast(message: "保存しました")
    }

    /*func showSaveToast() {
        toastLabel?.removeFromSuperview()
        let label = UILabel()
        label.text = "保存しました"
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        label.textAlignment = .center
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.alpha = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        toastLabel = label
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -50),
            label.widthAnchor.constraint(equalToConstant: 150),
            label.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        UIView.animate(withDuration: 0.3, animations: {
            label.alpha = 1
        }) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                UIView.animate(withDuration: 0.3, animations: {
                    label.alpha = 0
                }, completion: { _ in
                    label.removeFromSuperview()
                })
            }
        }
    }*/


    
    private func saveNote() {
        guard let note = note else { return }

        let textToSave = textView.text ?? ""

        if textToSave.isEmpty {
            if viewContext.registeredObjects.contains(note) {
                viewContext.delete(note)
            }
        } else {
            note.content = textToSave
            let mutableAttr = NSMutableAttributedString(string: textToSave)
            let linkedAttr = NSMutableAttributedString.withLinkDetection(from: mutableAttr)
            note.attributedContent = try? linkedAttr.data(
                from: NSRange(location: 0, length: linkedAttr.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
            )
            if note.date == nil {
                note.date = Date()
            }
        }

        do {
            try viewContext.save()
            didSave = true
            //showToast(message: "保存しました")  // 成功時もトースト
        } catch {
            let nsError = error as NSError
            var message = "保存できませんでした: \(nsError.localizedDescription)"
            if nsError.code == NSFileWriteOutOfSpaceError {
                message = "ストレージ不足で保存できませんでした。"
            }
            Toast.showToast(message: message)  // 失敗時もトースト
        }

    }
    
    // MARK: - Keyboard Handling
    @objc private func keyboardWillShow(_ notification: Notification) {
        if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
            textView.contentInset.bottom = frame.height
            textView.scrollIndicatorInsets.bottom = frame.height
        }
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        textView.contentInset.bottom = 0
        textView.scrollIndicatorInsets.bottom = 0
    }
    
    // MARK: - Toast 表示
    func showCopyToast() {
        toastLabel?.removeFromSuperview()
        let label = UILabel()
        label.text = "コピーしました"
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        label.textAlignment = .center
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        toastLabel = label
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -50),
            label.widthAnchor.constraint(equalToConstant: 150),
            label.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        UIView.animate(withDuration: 0.3, animations: {
            label.alpha = 1
        }) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                UIView.animate(withDuration: 0.3, animations: {
                    label.alpha = 0
                }, completion: { _ in
                    label.removeFromSuperview()
                })
            }
        }
    }
}
