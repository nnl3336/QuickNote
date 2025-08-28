//
//  UIViewController .swift
//  QuickNote
//
//  Created by Yuki Sasaki on 2025/08/26.
//

import SwiftUI
import CoreData
import Combine

class NotesViewController: UIViewController, UISearchBarDelegate, NSFetchedResultsControllerDelegate {

    var viewContext: NSManagedObjectContext!

    private var fetchedResultsController: NSFetchedResultsController<Note>!

    let tableView = UITableView()
    let searchBar = UISearchBar()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "メモ一覧"

        setupSearchBar()
        setupTableView()
        setupFloatingButton()
        setupFetchedResultsController()
    }

    // MARK: - Setup
    private func setupSearchBar() {
        searchBar.placeholder = "検索"
        searchBar.delegate = self
        searchBar.returnKeyType = .search
        navigationItem.titleView = searchBar
    }

    private func setupTableView() {
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        tableView.keyboardDismissMode = .interactive

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupFloatingButton() {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "plus"), for: .normal)
        button.tintColor = .white
        button.backgroundColor = view.tintColor
        button.layer.cornerRadius = 28
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.3
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.addTarget(self, action: #selector(addNote), for: .touchUpInside)
        view.addSubview(button)

        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 56),
            button.heightAnchor.constraint(equalToConstant: 56),
            button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }

    private func setupFetchedResultsController() {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.date, ascending: false)]

        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: viewContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        fetchedResultsController.delegate = self

        do {
            try fetchedResultsController.performFetch()
        } catch {
            print("FRC fetch failed: \(error)")
        }

        tableView.dataSource = self
    }

    // MARK: - Add Note
    @objc private func addNote() {
        let editorVC = NoteEditorViewController()
        editorVC.viewContext = viewContext
        editorVC.onSave = { [weak self] in
            // 保存後は FRC が自動で反映するので reload は不要
        }
        navigationController?.pushViewController(editorVC, animated: true)
    }

    // MARK: - Search
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            fetchedResultsController.fetchRequest.predicate = nil
        } else {
            fetchedResultsController.fetchRequest.predicate = NSPredicate(format: "content CONTAINS[cd] %@", searchText)
        }
        do {
            try fetchedResultsController.performFetch()
            tableView.reloadData()
        } catch {
            print(error)
        }
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    // MARK: - Scroll keyboard
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        searchBar.resignFirstResponder()
    }

    // MARK: - Swipe Delete
    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {

        let deleteAction = UIContextualAction(style: .destructive, title: "削除") { [weak self] _, _, completionHandler in
            guard let self = self else { return }

            let noteToDelete = self.fetchedResultsController.object(at: indexPath)
            self.viewContext.delete(noteToDelete)
            do {
                try self.viewContext.save()
            } catch {
                print("削除エラー: \(error)")
            }

            completionHandler(true)
        }

        let configuration = UISwipeActionsConfiguration(actions: [deleteAction])
        configuration.performsFirstActionWithFullSwipe = true
        return configuration
    }

    // MARK: - FRC Delegate
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                    didChange anObject: Any,
                    at indexPath: IndexPath?,
                    for type: NSFetchedResultsChangeType,
                    newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            if let newIndexPath = newIndexPath { tableView.insertRows(at: [newIndexPath], with: .automatic) }
        case .delete:
            if let indexPath = indexPath { tableView.deleteRows(at: [indexPath], with: .automatic) }
        case .update:
            if let indexPath = indexPath { tableView.reloadRows(at: [indexPath], with: .automatic) }
        case .move:
            if let indexPath = indexPath, let newIndexPath = newIndexPath {
                tableView.moveRow(at: indexPath, to: newIndexPath)
            }
        @unknown default:
            break
        }
    }
}

// MARK: - UITableViewDataSource
extension NotesViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        fetchedResultsController.fetchedObjects?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let note = fetchedResultsController.object(at: indexPath)
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var config = cell.defaultContentConfiguration()
        config.text = note.content ?? ""
        config.textProperties.numberOfLines = 1
        cell.contentConfiguration = config
        return cell
    }
}

// MARK: - UITableViewDelegate
extension NotesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let note = fetchedResultsController.object(at: indexPath)
        let editorVC = NoteEditorViewController()
        editorVC.note = note
        editorVC.viewContext = viewContext
        navigationController?.pushViewController(editorVC, animated: true)
    }
}

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
