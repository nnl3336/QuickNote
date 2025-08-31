//
//  UICollectionView .swift
//  QuickNote
//
//  Created by Yuki Sasaki on 2025/08/28.
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
    
    // MARK: - UISearchBarDelegate
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        // フォーカスが当たったら Cancel と Clear ボタンを表示
        showSearchButtons()
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
    
    // 🔍ボタン
    let addButton = UIButton(type: .system)
    let searchButton = UIButton(type: .system)
    let cancelButton = UIButton(type: .system)
    let clearButton = UIButton(type: .system)
    let buttonStack = UIStackView()
    
    private func setupFloatingButton() {
        // ボタンの設定
        addButton.setImage(UIImage(systemName: "plus"), for: .normal)
        addButton.tintColor = .white
        addButton.backgroundColor = .systemBlue
        addButton.layer.cornerRadius = 28
        addButton.translatesAutoresizingMaskIntoConstraints = false
        
        searchButton.setImage(UIImage(systemName: "magnifyingglass"), for: .normal)
        searchButton.tintColor = .white
        searchButton.backgroundColor = .systemBlue
        searchButton.layer.cornerRadius = 28
        searchButton.translatesAutoresizingMaskIntoConstraints = false
        
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal) // ← ここ追加
        cancelButton.backgroundColor = .systemRed
        cancelButton.layer.cornerRadius = 28
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        
        clearButton.setTitle("Clear", for: .normal)
        clearButton.setTitleColor(.white, for: .normal) // ← ここ追加
        clearButton.backgroundColor = .systemGray
        clearButton.layer.cornerRadius = 28
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        
        addButton.addTarget(self, action: #selector(addNote), for: .touchUpInside)
        searchButton.addTarget(self, action: #selector(toggleSearchBar), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelSearch), for: .touchUpInside)
        clearButton.addTarget(self, action: #selector(clearSearch), for: .touchUpInside)
        
        // StackView 初期化
        buttonStack.axis = .horizontal
        buttonStack.spacing = 16
        buttonStack.alignment = .center
        buttonStack.distribution = .fill
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        // ✅ ボタンを StackView に追加
        buttonStack.addArrangedSubview(searchButton)
        buttonStack.addArrangedSubview(addButton)
        
        view.addSubview(buttonStack)
        
        // ボタンのサイズ固定
        NSLayoutConstraint.activate([
            addButton.widthAnchor.constraint(equalToConstant: 56),
            addButton.heightAnchor.constraint(equalToConstant: 56),
            searchButton.widthAnchor.constraint(equalToConstant: 56),
            searchButton.heightAnchor.constraint(equalToConstant: 56),
            cancelButton.widthAnchor.constraint(equalToConstant: 56),
            cancelButton.heightAnchor.constraint(equalToConstant: 56),
            clearButton.widthAnchor.constraint(equalToConstant: 56),
            clearButton.heightAnchor.constraint(equalToConstant: 56)
        ])

        // StackView を右下に固定
        NSLayoutConstraint.activate([
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            buttonStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }

    // 切り替え関数も viewDidLoad 内の setup から呼べます
    func showNormalButtons() {
        buttonStack.arrangedSubviews.forEach { $0.isHidden = false }
        cancelButton.isHidden = true
        clearButton.isHidden = true
    }
    
    func showSearchButtons() {
        buttonStack.arrangedSubviews.forEach { $0.isHidden = true }
        cancelButton.isHidden = false
        clearButton.isHidden = false
        
        // StackView を入れ替える
        buttonStack.arrangedSubviews.forEach { buttonStack.removeArrangedSubview($0) }
        buttonStack.addArrangedSubview(clearButton)
        buttonStack.addArrangedSubview(cancelButton)
    }
    
    
    @objc private func cancelSearch() {
        searchBar.text = ""              // 入力を全消し
        fetchedResultsController.fetchRequest.predicate = nil // 検索条件をリセット
        searchBar.resignFirstResponder()

        // StackView を通常ボタンに切り替え
        buttonStack.arrangedSubviews.forEach { buttonStack.removeArrangedSubview($0); $0.removeFromSuperview() }
        buttonStack.addArrangedSubview(searchButton)
        buttonStack.addArrangedSubview(addButton)
        
        showNormalButtons() // isHidden リセット
        
        do {
            try fetchedResultsController.performFetch()
            tableView.reloadData()
        } catch {
            print("検索リセットエラー: \(error)")
        }
    }

    
    @objc private func clearSearch() {
        searchBar.text = ""              // 入力を全消し
        fetchedResultsController.fetchRequest.predicate = nil // 検索条件をリセット
        
        do {
            try fetchedResultsController.performFetch()
            tableView.reloadData()
        } catch {
            print("検索リセットエラー: \(error)")
        }
    }
    
    @objc private func toggleSearchBar() {
        searchBar.becomeFirstResponder()   // ← フォーカスしてすぐ入力できる
        showSearchButtons()
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
            let keywords = searchText.components(separatedBy: " ").filter { !$0.isEmpty }
            guard !keywords.isEmpty else { return }
            
            // 最初のキーワードだけ predicate 作成
            var predicateFormat = "content CONTAINS[cd] %@"
            var arguments: [Any] = [keywords[0]]
            
            // 2つ目以降のキーワードに対して順番を考慮しつつ部分一致
            for keyword in keywords.dropFirst() {
                predicateFormat += " AND content CONTAINS[cd] %@"
                arguments.append(keyword)
            }
            
            fetchedResultsController.fetchRequest.predicate = NSPredicate(format: predicateFormat, argumentArray: arguments)
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
    // MARK: - Swipe Delete
    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        let deleteAction = UIContextualAction(style: .destructive, title: "削除") { [weak self] _, _, completionHandler in
            guard let self = self else { return }
            
            // アラート表示
            let alert = UIAlertController(title: "確認", message: "このメモを削除しますか？", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel) { _ in
                completionHandler(false) // 削除しない
            })
            alert.addAction(UIAlertAction(title: "削除", style: .destructive) { _ in
                let noteToDelete = self.fetchedResultsController.object(at: indexPath)
                self.viewContext.delete(noteToDelete)
                do {
                    try self.viewContext.save()
                } catch {
                    print("削除エラー: \(error)")
                }
                completionHandler(true) // 削除完了
            })
            
            self.present(alert, animated: true)
        }
        
        let configuration = UISwipeActionsConfiguration(actions: [deleteAction])
        configuration.performsFirstActionWithFullSwipe = false // ← フルスワイプで即削除されないようにする
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

