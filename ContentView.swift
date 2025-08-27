//
//  ContentView.swift
//  QuickNote
//
//  Created by Yuki Sasaki on 2025/08/25.
//

import SwiftUI
import CoreData
import Combine

// MARK: - ContentView
struct ContentView: UIViewControllerRepresentable {
    @Environment(\.managedObjectContext) private var viewContext

    func makeUIViewController(context: Context) -> UINavigationController {
        let notesVC = NotesViewController()
        notesVC.viewContext = viewContext
        let nav = UINavigationController(rootViewController: notesVC)
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // 特に更新処理は不要
    }
}

class NotesViewController: UITableViewController, UISearchBarDelegate {

    var viewContext: NSManagedObjectContext!
    var notes: [Note] = []
    var filteredNotes: [Note] = []

    let searchBar = UISearchBar()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "メモ一覧"

        // 検索バーをナビゲーションに追加
        searchBar.placeholder = "検索"
        searchBar.delegate = self
        navigationItem.titleView = searchBar

        // UITableView セル登録
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")

        // データ読み込み
        fetchNotes()
    }

    private func fetchNotes() {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.date, ascending: false)]
        do {
            notes = try viewContext.fetch(request)
            filteredNotes = notes
            tableView.reloadData()
        } catch {
            print("Fetch failed: \(error)")
        }
    }

    // MARK: - UITableViewDataSource
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredNotes.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let note = filteredNotes[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var config = cell.defaultContentConfiguration()
        config.text = note.content ?? ""
        if let date = note.date {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            config.secondaryText = formatter.string(from: date)
        }

        // ★ ここで1行に制限
        config.textProperties.numberOfLines = 1
        config.textProperties.lineBreakMode = .byTruncatingTail

        cell.contentConfiguration = config
        return cell
    }

    // MARK: - UITableViewDelegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let note = filteredNotes[indexPath.row]
        let editorVC = NoteEditorViewController()
        editorVC.note = note
        editorVC.viewContext = viewContext
        navigationController?.pushViewController(editorVC, animated: true)
    }

    override func tableView(_ tableView: UITableView,
                            commit editingStyle: UITableViewCell.EditingStyle,
                            forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let noteToDelete = filteredNotes[indexPath.row]
            viewContext.delete(noteToDelete)
            try? viewContext.save()
            fetchNotes()
        }
    }

    // MARK: - UISearchBarDelegate
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            filteredNotes = notes
        } else {
            filteredNotes = notes.filter { $0.content?.localizedCaseInsensitiveContains(searchText) ?? false }
        }
        tableView.reloadData()
    }
}


//


class NoteEditorViewController: UIViewController, UITextViewDelegate {
    
    var viewContext: NSManagedObjectContext!
    var note: Note?    // 編集対象ノート（nilなら新規）
    
    private var textView: UITextView!
    private var toastLabel: UILabel?
    private var didSave = false
    private var isCancelling = false
    
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
        
        loadContent()
        
        // キーボード通知
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillShow(_:)),
                                               name: UIResponder.keyboardWillShowNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillHide(_:)),
                                               name: UIResponder.keyboardWillHideNotification,
                                               object: nil)
    }
    
    private func setupTextView() {
        textView = UITextView(frame: .zero)
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.font = UIFont.systemFont(ofSize: 18)
        textView.delegate = self
        view.addSubview(textView)
        
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            textView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        textView.becomeFirstResponder()
    }
    
    private func setupNavigationItems() {
        navigationItem.title = note?.content?.isEmpty ?? true ? "新しいメモ" : "メモを編集"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "キャンセル",
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "保存",
            style: .done,
            target: self,
            action: #selector(saveTapped)
        )
    }
    
    private func loadContent() {
        if let data = note?.attributedContent,
           let attr = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtfd],
                documentAttributes: nil
           ) {
            textView.attributedText = attr
        } else {
            textView.text = note?.content ?? ""
        }
    }
    
    @objc private func cancelTapped() {
        isCancelling = true
        navigationController?.popViewController(animated: true)
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
            note.attributedContent = try? textView.attributedText.data(
                from: NSRange(location: 0, length: textView.attributedText.length),
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
