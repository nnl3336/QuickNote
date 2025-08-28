//
//  UITextView.swift
//  QuickNote
//
//  Created by Yuki Sasaki on 2025/08/28.
//

import SwiftUI
import CoreData

// MARK: - UITextView
class NoteEditorViewController: UIViewController, UITextViewDelegate {

    var viewContext: NSManagedObjectContext!
    var note: Note?    // 編集対象ノート（nilなら新規）
    
    // ← これを追加
    var onSave: (() -> Void)?
    
    private var textView: UITextView!
    private var toastLabel: UILabel?
    private var didSave = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        setupTextView()
        setupNavigationItems()
        
        // 新規作成の場合は Note を生成
        if note == nil {
            let newNote = Note(context: viewContext)
            newNote.id = UUID()
            newNote.date = Date()
            self.note = newNote
        }
        
        //ロード
        loadContent()
        
        // キーボード通知
        /*NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillShow(_:)),
                                               name: UIResponder.keyboardWillShowNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillHide(_:)),
                                               name: UIResponder.keyboardWillHideNotification,
                                               object: nil)*/
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // ナビゲーションで戻るときだけ保存
        if self.isMovingFromParent {
            saveNote()
        }
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

        

        // キーボード上にツールバー
        textView.inputAccessoryView = createToolbar()
        
        view.addSubview(textView)
        
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            textView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        loadContent()
        
        // 新規ノートならキーボードを出す
        if note == nil {
            textView.becomeFirstResponder()
        }
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


    @objc private func copyText() {
        UIPasteboard.general.string = textView.text
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
        let normalColor = UIColor.label  // ← 自動でライト/ダーク対応
        let linkColor = UIColor.systemBlue
        let font = UIFont.systemFont(ofSize: 20)
        
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
            
        } else if let content = note?.content {
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
        } else {
            textView.text = ""
            textView.font = font
            textView.textColor = normalColor
        }
    }

    
    
    @objc private func saveTapped() {
        saveNote()
        navigationController?.popViewController(animated: true)
    }
    
    private func saveNote() {
        guard let note = note else { return }
        
        let trimmed = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            if viewContext.registeredObjects.contains(note) {
                viewContext.delete(note)
            }
        } else {
            note.content = trimmed
            
            // 現在のテキストにリンク検出をして属性を付与
            let mutableAttr = NSMutableAttributedString(string: trimmed)
            let linkedAttr = NSMutableAttributedString.withLinkDetection(from: mutableAttr)
            
            // RTFD データとして保存
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
        } catch {
            print("保存エラー: \(error)")
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
