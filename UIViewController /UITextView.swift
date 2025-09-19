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
class NoteEditorViewController: UIViewController, UITextViewDelegate, UITextPasteDelegate, UITextFieldDelegate {
    

    var viewContext: NSManagedObjectContext!
    var note: Note?    // 編集対象ノート（nilなら新規）
    
    // ← これを追加
    var onSave: (() -> Void)?
    
    private var textView: UITextView!
    private var toastLabel: UILabel?
    private var didSave = false
    
    private var dateLabel: UILabel!
    
    // ここにプロパティを追加
       private var undoButton: UIBarButtonItem!
       private var redoButton: UIBarButtonItem!
       private var copyButton: UIBarButtonItem!
       private var likeButton: UIBarButtonItem!
       private var checkButton: UIBarButtonItem!
    
    //***
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        
        
        
        setupDateLabel()    // 先にラベルを作る
        setupTextView()     // textView はここで1回だけ作る
        setupNavigationItems()
        
        // 既存の編集用ツールバー
        defaultToolbar = createToolbar()
        // 検索用ツールバー
        searchToolbar = createSearchToolbar()
        toolbarState = .default
        
        //ロード
        loadContent()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
                
        linkedFolderAction = UIAction(title: "フォルダを開く", image: nil) { action in
            print("フォルダ開く処理")
        }
    }

    //***
    
    
    //PhotosPicker　画像挿入
    func insertImage(_ image: UIImage) {
        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)

        let attrString = NSAttributedString(attachment: attachment)
        let mutableAttr = NSMutableAttributedString(attributedString: textView.attributedText)

        let selectedRange = textView.selectedRange
        mutableAttr.insert(attrString, at: selectedRange.location)

        // 📌 次の文字が改行でない場合だけ改行を入れる
        if selectedRange.location < mutableAttr.length {
            let nextChar = mutableAttr.attributedSubstring(from: NSRange(location: selectedRange.location, length: 1)).string
            if nextChar != "\n" {
                mutableAttr.insert(NSAttributedString(string: "\n"), at: selectedRange.location + 1)
            }
        } else {
            // 末尾なら改行を追加
            mutableAttr.insert(NSAttributedString(string: "\n"), at: selectedRange.location + 1)
        }

        textView.attributedText = mutableAttr
        textView.selectedRange = NSRange(location: selectedRange.location + 2, length: 0)
    }

    
    
    // MARK: - UITextPasteDelegate　貼り付け時　ペースト
    func textPasteConfigurationSupporting(_ textPasteConfigurationSupporting: UITextPasteConfigurationSupporting,
                                          transform item: UITextPasteItem) {

        let normalColor: UIColor = traitCollection.userInterfaceStyle == .dark ? .white : .black
        let linkColor = UIColor.systemBlue
        let font = UIFont.systemFont(ofSize: 20)

        func cleanInvisibleLinks(_ attr: NSMutableAttributedString) {
            let fullRange = NSRange(location: 0, length: attr.length)
            attr.enumerateAttribute(.link, in: fullRange) { value, range, _ in
                guard value != nil else { return }
                let substring = attr.attributedSubstring(from: range).string
                if substring.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    attr.removeAttribute(.link, range: range)
                }
            }
        }

        func processAttributedString(_ mutable: NSMutableAttributedString) -> NSMutableAttributedString {
            let linkedAttr = NSMutableAttributedString.withLinkDetection(from: mutable)

            linkedAttr.addAttribute(.font, value: font, range: NSRange(location: 0, length: linkedAttr.length))
            linkedAttr.addAttribute(.foregroundColor, value: normalColor, range: NSRange(location: 0, length: linkedAttr.length))

            linkedAttr.enumerateAttribute(.link, in: NSRange(location: 0, length: linkedAttr.length)) { value, range, _ in
                if value != nil {
                    linkedAttr.addAttribute(.foregroundColor, value: linkColor, range: range)
                }
            }


            // ★ リンクの前後にスペースを挿入（非リンク属性付き）
            linkedAttr.surroundLinksWithSpaces(normalColor: normalColor, font: font)

            return linkedAttr
        }


        if item.itemProvider.canLoadObject(ofClass: NSAttributedString.self) {
            item.itemProvider.loadObject(ofClass: NSAttributedString.self) { object, error in
                if let attr = object as? NSAttributedString {
                    let mutable = NSMutableAttributedString(attributedString: attr)
                    let resultAttr = processAttributedString(mutable)
                    DispatchQueue.main.async {
                        item.setResult(attributedString: resultAttr)
                    }
                }
            }
        } else if item.itemProvider.canLoadObject(ofClass: String.self) {
            item.itemProvider.loadObject(ofClass: String.self) { object, error in
                if let str = object as? String {
                    let mutable = NSMutableAttributedString(string: str)
                    let resultAttr = processAttributedString(mutable)
                    DispatchQueue.main.async {
                        item.setResult(attributedString: resultAttr)
                    }
                }
            }
        }
    }

    /*func handlePaste(into attributedString: NSMutableAttributedString, range: NSRange, pastedText: String) {
        // フォントと通常文字色を設定
        let font = UIFont.systemFont(ofSize: 20) // フォントサイズ20
        let pastedAttr = NSMutableAttributedString(string: pastedText)
        pastedAttr.addAttribute(.foregroundColor, value: UIColor.label, range: NSRange(location: 0, length: pastedAttr.length))
        pastedAttr.addAttribute(.font, value: font, range: NSRange(location: 0, length: pastedAttr.length))
        
        // リンクを検出
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: pastedText, options: [], range: NSRange(location: 0, length: pastedText.utf16.count)) ?? []

        for match in matches {
            if let url = match.url, url.absoluteString.hasPrefix("http") {
                // httpリンクだけ青色
                pastedAttr.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: match.range)
            }
        }

        // 元の attributedString に貼り付け
        attributedString.replaceCharacters(in: range, with: pastedAttr)
    }*/

    
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

    //セットアップ
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
            dateLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor) // safeArea ではなく view
        ])
    }


    @objc func appWillResignActive() {
        saveNoteOnExit()
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
    
    //セットアッ
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
        
        
        //loadContent()
        
        // 新規ノートならキーボードを出す
        if note == nil {
            let newNote = Note(context: viewContext)
            newNote.id = UUID()
            newNote.date = Date()
            
            self.note = newNote

            // ★ ビューが表示された後にキーボードを出す
            DispatchQueue.main.async {
                self.textView.becomeFirstResponder()
            }
        }
    }
    
    //***
    
    
    
    /*private func applyLinkAttributes(to textView: UITextView) {
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
    }*/

    //テキストエディター変更
    @objc private func textViewDidChangeNotification(_ notification: Notification) {
        guard let textView = notification.object as? UITextView else { return }
        
        // 変換中は無視
        if textView.markedTextRange != nil { return }
        
        // 最後の操作がペーストかどうか判定
        /*if UIPasteboard.general.hasStrings {
            applyLinkAttributes(to: textView)
        }*/
    }
    
    /*private func applyLinkAttributesToPastedText() {
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
    }*/

    
    /*override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(paste(_:)) {
            DispatchQueue.main.async {
                self.applyLinkAttributesToPastedText()
            }
        }
        return super.canPerformAction(action, withSender: sender)
    }*/





    /// 入力テキスト中の URL を検出して NSMutableAttributedString にリンク属性を付与する
    /*func attributedStringByDetectingLinks(in text: String, font: UIFont, textColor: UIColor, linkColor: UIColor) -> NSMutableAttributedString {
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
    }*/

    // MARK: - 検索用ツールバー 検索キーボードツールバー
    private func createSearchToolbar() -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        
        // UITextField を作成
        let searchField = UITextField(frame: CGRect(x: 0, y: 0, width: 200, height: 30))
        searchField.borderStyle = .roundedRect
        searchField.placeholder = "検索"
        searchField.returnKeyType = .search
        searchField.delegate = self  // UITextFieldDelegate を使う場合
        
        // UITextField にフォーカス
        searchField.becomeFirstResponder()
        
        // UITextField を UIBarButtonItem に
        let searchItem = UIBarButtonItem(customView: searchField)
        
        // 前へ / 次へ / 閉じる
        let prev = UIBarButtonItem(title: "前へ", style: .plain, target: self, action: #selector(searchPrev))
        let next = UIBarButtonItem(title: "次へ", style: .plain, target: self, action: #selector(searchNext))
        let close = UIBarButtonItem(title: "閉じる", style: .done, target: self, action: #selector(closeSearch))
        
        // Flexible space を間に挟む
        let flex = UIBarButtonItem.flexibleSpace()
        
        toolbar.items = [prev, flex, searchItem, flex, next, flex, close]
        return toolbar
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        let keyword = textField.text ?? ""
        performSearch(keyword: keyword)
        textField.resignFirstResponder() // キーボードを閉じる
        return true
    }
    
    private var searchKeyword: String = ""
    private var searchResults: [NSRange] = []
    private var currentSearchIndex: Int = 0

    
    private func performSearch(keyword: String) {
        print("検索キーワード:", keyword)

        searchKeyword = keyword
        searchResults.removeAll()
        currentSearchIndex = 0
        
        let text = textView.text ?? ""
        let attributed = NSMutableAttributedString(string: text)
        
        // ハイライト色
        let highlightColor = UIColor.yellow
        
        let pattern = NSRegularExpression.escapedPattern(for: keyword)
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            let range = NSRange(location: 0, length: text.utf16.count)
            regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                if let matchRange = match?.range {
                    attributed.addAttribute(.backgroundColor, value: highlightColor, range: matchRange)
                    searchResults.append(matchRange) // 検索結果を保持
                }
            }
        }
        
        textView.attributedText = attributed
        
        // 最初の検索結果を選択
        scrollToSearchResult(index: 0)
    }
    private func scrollToSearchResult(index: Int) {
        guard !searchResults.isEmpty else { return }
        
        let safeIndex = max(0, min(index, searchResults.count - 1))
        currentSearchIndex = safeIndex
        
        let range = searchResults[safeIndex]
        textView.scrollRangeToVisible(range)
        
        // 選択状態にする
        textView.selectedRange = range
    }




    
    // MARK: - 検索ツールバーアクション
    @objc private func searchPrev() {
        guard !searchResults.isEmpty else { return }
        currentSearchIndex = (currentSearchIndex - 1 + searchResults.count) % searchResults.count
        scrollToSearchResult(index: currentSearchIndex)
    }

    @objc private func searchNext() {
        guard !searchResults.isEmpty else { return }
        currentSearchIndex = (currentSearchIndex + 1) % searchResults.count
        scrollToSearchResult(index: currentSearchIndex)
    }

        @objc private func closeSearch() {
            toolbarState = .default
        }
    
// MARK: - キーボードツールバー　通常キーボードツールバー
    private func createToolbar() -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        
        // Copy
        copyButton = UIBarButtonItem(
            image: UIImage(systemName: "doc.on.doc"),
            style: .plain,
            target: self,
            action: #selector(copyText)
        )
        
        // Undo / Redo
        undoButton = UIBarButtonItem(barButtonSystemItem: .undo, target: self, action: #selector(undoAction))
        redoButton = UIBarButtonItem(barButtonSystemItem: .redo, target: self, action: #selector(redoAction))
        
        // Like ❤️
        likeButton = UIBarButtonItem(
            image: UIImage(systemName: "heart"),
            style: .plain,
            target: self,
            action: #selector(toggleLike)
        )
        
        // Check ✅
        checkButton = UIBarButtonItem(
            image: UIImage(systemName: "checkmark.circle"),
            style: .plain,
            target: self,
            action: #selector(toggleCheck)
        )
        
        // 新規作成ボタン
        let newButton = UIBarButtonItem(
            image: UIImage(systemName: "plus.circle"),
            style: .plain,
            target: self,
            action: #selector(createNew)
        )
        
        // 写真追加ボタン
        let photoButton = UIBarButtonItem(
            image: UIImage(systemName: "photo"),
            style: .plain,
            target: self,
            action: #selector(addPhoto)
        )
        
        // Flexible spaces
        let flex1 = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let flex2 = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let flex3 = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let flex4 = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let flex5 = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let flex6 = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        toolbar.items = [
            undoButton, flex1,
            copyButton, flex2,
            redoButton, flex3,
            likeButton, flex4,
            checkButton, flex5,
            photoButton, flex6,
            newButton,
             
        ]
        
        return toolbar
    }
    @objc private func createNew() {
        print("新規作成 tapped")
        // 新規作成の処理
        saveNote()
        
        initialize()
        
        
        Toast.showToast(message: "保存しました")
    }
    func initialize() {
        // 例: モデルの新規作成
        let newNote = Note(context: viewContext)
        textView.attributedText = NSMutableAttributedString(string: "")
        newNote.date = Date()
        newNote.isLiked = false
        newNote.isCheck = false
        
        self.note = newNote

    }

    @objc private func addPhoto() {
        print("写真追加 tapped")
    }


    // メモリ上だけで管理するフラグ
    private var isLikedState: Bool = false

    @objc private func toggleLike() {
        // 状態を反転
        isLikedState.toggle()
        
        // ボタンの見た目を更新
        likeButton?.image = isLikedState ? UIImage(systemName: "heart.fill") : UIImage(systemName: "heart")
    }


    // メモリ上だけで管理するフラグ
    private var isCheckState: Bool = false

    @objc private func toggleCheck() {
        // 状態を反転
        isCheckState.toggle()
        
        // ボタンの見た目更新
        checkButton.image = isCheckState
            ? UIImage(systemName: "checkmark.circle.fill")
            : UIImage(systemName: "checkmark.circle")
    }



    //アップデートボタン
    private func updateUndoRedoButtons() {
            guard let um = textView.undoManager else {
                undoButton.isEnabled = false
                redoButton.isEnabled = false
                return
            }
            undoButton.isEnabled = um.canUndo
            redoButton.isEnabled = um.canRedo
        }

        // 編集のたびに状態を更新
        func textViewDidChange(_ textView: UITextView) { updateUndoRedoButtons() }
        func textViewDidBeginEditing(_ textView: UITextView) { updateUndoRedoButtons() }

        @objc private func undoAction() {
            textView.undoManager?.undo()
            updateUndoRedoButtons()
        }

        @objc private func redoAction() {
            textView.undoManager?.redo()
            updateUndoRedoButtons()
        }

    
//コピー
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

    
    // MARK: - ツールバー状態
    enum KeyboardToolbarState {
        case `default`  // 通常ツールバー
        case search     // 検索用ツールバー
    }
    
    private var toolbarState: KeyboardToolbarState = .default {
            didSet { updateToolbar() }
        }
    
    private var defaultToolbar: UIToolbar!
        private var searchToolbar: UIToolbar!
    
    // MARK: - ツールバー更新
    private func updateToolbar() {
        switch toolbarState {
        case .default:
            textView.inputAccessoryView = defaultToolbar
        case .search:
            textView.inputAccessoryView = searchToolbar
        }
        textView.reloadInputViews()
        textView.becomeFirstResponder()
    }

    // MARK: - ナビゲーションバー用プロパティ
        var linkedFolderAction: UIAction?
        var duplicateAction: UIAction!
        var searchInEditorAction: UIAction!
        var deleteAction: UIAction!
        var menuButton: UIBarButtonItem!
    
    // MARK: - ナビゲーションバー
    private func setupNavigationItems() {
        navigationItem.title = note?.content?.isEmpty ?? true ? "新しいメモ" : "メモを編集"

            // 保存ボタン
            let saveButton = UIBarButtonItem(
                title: "保存",
                style: .done,
                target: self,
                action: #selector(saveTapped)
            )

            duplicateAction = UIAction(title: "複製", image: UIImage(systemName: "doc.on.doc")) { _ in
                self.duplicateItem(note: self.note)
            }

            searchInEditorAction = UIAction(title: "エディター内検索", image: UIImage(systemName: "magnifyingglass")) { _ in
                self.searchInEditor()
            }

            deleteAction = UIAction(title: "削除", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                self.deleteItem()
            }

            // メニューボタンをクラスプロパティとして生成
            menuButton = UIBarButtonItem(
                image: UIImage(systemName: "ellipsis.circle"),
                style: .plain,
                target: nil,
                action: nil
            )
        
        /*linkedFolderAction = UIAction(title: "フォルダを開く", image: UIImage(systemName: "folder"), handler: { _ in
            self.openLinkedFolder()
        })*/


        let menu = UIMenu(title: "", children: [
            //linkedFolderAction,
            duplicateAction,
            searchInEditorAction,
            deleteAction
        ])

        menuButton.menu = menu

            menuButton.primaryAction = nil

            navigationItem.rightBarButtonItems = [saveButton, menuButton]
        }
    var selectedItems: Set<Note> = []

    // MARK: - アクションメソッド
    private func openLinkedFolder(_ item: Note) {
        print("紐付きフォルダー")
        self.selectedItems = [item]         // ここで対象を入れる
    }

    private func duplicateItem(note: Note?) {
        let newNote = Note(context: viewContext)
        newNote.content = note?.content ?? "no duplicated text"
        newNote.date = Date() // 現在日時にする
        do {
            try viewContext?.save()
            print("Core Data アイテムを複製しました")
        } catch {
            print("複製エラー: \(error)")
        }
        self.note = newNote
        
        Toast.showToast(message: "アイテムを複製しました")
    }

    private func searchInEditor() {
        print("エディター内検索")
        // トグル
            toolbarState = (toolbarState == .default) ? .search : .default

        //updateToolbar()          // これで inputAccessoryView が切り替わる
    }

    private var isDeleting = false // 削除時は true にするフラグ

    private func deleteItem() {
        let alert = UIAlertController(
            title: "削除の確認",
            message: "本当に削除しますか？",
            preferredStyle: .alert
        )
        
        let deleteAction = UIAlertAction(title: "削除", style: .destructive) { [weak self] _ in
            guard let self = self, let note = self.note else { return }
            
            self.isDeleting = true
            
            // CoreData から削除
            self.viewContext.delete(note)
            try? viewContext.save()
            
            Toast.showToast(message: "アイテムを削除しました")
            
            // 前の画面に戻る
            self.navigationController?.popViewController(animated: true)
        }
        
        let cancelAction = UIAlertAction(title: "キャンセル", style: .cancel)
        
        alert.addAction(deleteAction)
        alert.addAction(cancelAction)
        
        self.present(alert, animated: true)
    }

    

    
    //loadContent　ロード
    private func loadContent() {
        let linkColor = UIColor.systemBlue
        
        // 🔽 ここで UserDefaults からフォント設定を取得
        let savedSize = UserDefaults.standard.double(forKey: "fontSize")
        let fontSize = savedSize == 0 ? 16 : CGFloat(savedSize)
        
        let savedWeight = UserDefaults.standard.string(forKey: "fontWeight") ?? FontWeight.regular.rawValue
        let fontWeight = FontWeight(rawValue: savedWeight)?.uiFontWeight ?? .regular
        
        let font = UIFont.systemFont(ofSize: fontSize, weight: fontWeight)
        let normalColor = UIColor.label

        let applyAttributes: (NSMutableAttributedString) -> NSMutableAttributedString = { attr in
            attr.addAttribute(.font, value: font, range: NSRange(location: 0, length: attr.length))
            attr.addAttribute(.foregroundColor, value: normalColor, range: NSRange(location: 0, length: attr.length))

            // 既存リンクをリンク色に
            attr.enumerateAttribute(.link, in: NSRange(location: 0, length: attr.length)) { value, range, _ in
                if value != nil {
                    attr.addAttribute(.foregroundColor, value: linkColor, range: range)
                }
            }

            // データ検出でリンク追加
            if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
                let matches = detector.matches(in: attr.string, options: [], range: NSRange(location: 0, length: attr.length))
                for match in matches {
                    if let url = match.url {
                        if attr.attribute(.link, at: match.range.location, effectiveRange: nil) == nil {
                            attr.addAttribute(.link, value: url, range: match.range)
                            attr.addAttribute(.foregroundColor, value: linkColor, range: match.range)
                        }
                    }
                }
            }

            // ★ リンク前後にスペース追加
            attr.surroundLinksWithSpaces(normalColor: normalColor, font: font)

            return attr
        }

        if let data = note?.attributedContent,
           let attr = try? NSAttributedString(data: data,
                                              options: [.documentType: NSAttributedString.DocumentType.rtfd],
                                              documentAttributes: nil) {
            let mutableAttr = NSMutableAttributedString(attributedString: attr)
            let applied = applyAttributes(mutableAttr)
            resizeImagesIn(applied)
            textView.attributedText = applied
        }

        


        // メモリ上の状態に同期
        isLikedState = note?.isLiked ?? false
        isCheckState = note?.isCheck ?? false

        // UI 更新
        likeButton?.image = isLikedState ? UIImage(systemName: "heart.fill") : UIImage(systemName: "heart")
        checkButton?.image = isCheckState ? UIImage(systemName: "checkmark.circle.fill") : UIImage(systemName: "checkmark.circle")

        updateDateLabel()
    }
    // 複数画像や復元時のリサイズ処理　リサイズ
        func resizeImagesIn(_ attr: NSMutableAttributedString) {
            let fixedWidth: CGFloat = 200

            attr.enumerateAttribute(.attachment,
                                   in: NSRange(location: 0, length: attr.length)) { value, range, _ in
                guard let attachment = value as? NSTextAttachment else { return }

                // 画像を取得
                var image: UIImage? = nil
                if let img = attachment.image {
                    image = img
                } else if let data = attachment.contents,
                          let img = UIImage(data: data) {
                    image = img
                } else if let fileWrapper = attachment.fileWrapper,
                          let data = fileWrapper.regularFileContents,
                          let img = UIImage(data: data) {
                    image = img
                }

                if let image = image {
                    let resized = resizedImage(image, maxSize: fixedWidth)  // ← self 不要
                    attachment.image = resized
                    attachment.bounds = CGRect(x: 0, y: 0, width: resized.size.width, height: resized.size.height)
                }
                
            }

            textView.attributedText = attr
        }
    func resizedImage(_ image: UIImage, maxSize: CGFloat) -> UIImage {
        let aspectRatio = image.size.width / image.size.height
        var newWidth: CGFloat
        var newHeight: CGFloat
        
        if aspectRatio > 1 { // 横長
            newWidth = maxSize
            newHeight = maxSize / aspectRatio
        } else { // 縦長
            newHeight = maxSize
            newWidth = maxSize * aspectRatio
        }
        
        let newSize = CGSize(width: newWidth, height: newHeight)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage ?? image
    }
    

    
    //保存
    @objc private func saveTapped() {
        view.endEditing(true)  // キーボードを閉じる
        saveNote()
        //showSaveToast()        // ← 保存完了トーストを表示
        //navigationController?.popViewController(animated: true)
        //Toast.showToast(message: "保存しました")
        
        //トースト
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


    //保存saveNote()
    private func saveNote() {
        guard let note = note else { return }
        
        // 削除時は保存しない
        if isDeleting {
            return
        }

        if let attrText = textView.attributedText, attrText.length > 0 {
            // 本文の保存
            note.content = attrText.string
            note.attributedContent = try? attrText.data(
                from: NSRange(location: 0, length: attrText.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
            )

            // 添付の有無を判定
            var containsImage = false
            attrText.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attrText.length)) { value, _, stop in
                if value is NSTextAttachment {
                    containsImage = true
                    stop.pointee = true
                }
            }

            // 「文字は空（空白/改行だけ）だけど添付がある」＝画像だけのノート
            let trimmed = attrText.string.trimmingCharacters(in: .whitespacesAndNewlines)
            note.isImageOnly = containsImage && trimmed.isEmpty

            if note.date == nil {
                note.date = Date()
            }
        } else {
            // 完全に空なら削除
            if viewContext.registeredObjects.contains(note) {
                viewContext.delete(note)
                Toast.showToast(message: "破棄しました")
            }
            note.isImageOnly = false
        }

        // その他の状態保存
        note.isLiked = isLikedState
        note.isCheck = isCheckState

        // 保存処理
        do {
            try viewContext.save()
            if let attrText = textView.attributedText, attrText.length > 0 {
                Toast.showToast(message: "保存しました")
            }
        } catch {
            let nsError = error as NSError
            var message = "保存できませんでした: \(nsError.localizedDescription)"
            if nsError.code == NSFileWriteOutOfSpaceError {
                message = "ストレージ不足で保存できませんでした。"
            }
            Toast.showToast(message: message)
        }
    }

    //離脱保存
    private func saveNoteOnExit() {
        guard let note = note else { return }

        if let attrText = textView.attributedText {
            note.content = attrText.string
            note.attributedContent = try? attrText.data(
                from: NSRange(location: 0, length: attrText.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
            )

            // 画像が含まれているか判定
            var containsImage = false
            attrText.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attrText.length)) { value, range, stop in
                if value is NSTextAttachment {
                    containsImage = true
                    stop.pointee = true
                }
            }
            note.isContainsImage = containsImage

            if note.date == nil {
                note.date = Date()
            }
        } else {
            if viewContext.registeredObjects.contains(note) {
                viewContext.delete(note)
            }
            note.isContainsImage = false
        }

        note.isLiked = isLikedState
        note.isCheck = isCheckState

        do {
            try viewContext.save()
            Toast.showToast(message: "離脱保存しました")
        } catch {
            let nsError = error as NSError
            var message = "保存できませんでした: \(nsError.localizedDescription)"
            if nsError.code == NSFileWriteOutOfSpaceError {
                message = "ストレージ不足で保存できませんでした。"
            }
            Toast.showToast(message: message)
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
    
    // MARK: - Toast 表示　トースト
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
