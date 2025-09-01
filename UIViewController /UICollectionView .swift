//
//  UICollectionView .swift
//  QuickNote
//
//  Created by Yuki Sasaki on 2025/08/28.
//

import SwiftUI
import CoreData
import Combine

class NotesViewController: UIViewController, UISearchBarDelegate {

    var viewContext: NSManagedObjectContext!
    
    private var fetchedResultsController: NSFetchedResultsController<Note>!
    private var dataSource: UITableViewDiffableDataSource<Int, NSManagedObjectID>!
    
    let tableView = UITableView()
    let searchBar = UISearchBar()
    
    // 🔍ボタン
    let addButton = UIButton(type: .system)
    let searchButton = UIButton(type: .system)
    let cancelButton = UIButton(type: .system)
    let clearButton = UIButton(type: .system)
    let buttonStack = UIStackView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "メモ一覧"
        
        setupSearchBar()
        setupTableView()
        setupFloatingButton()
        setupFetchedResultsController()
        applySnapshot()
    }
    
    // MARK: - Cancel / Clear 検索
    @objc private func cancelSearch() {
        searchBar.text = ""
        fetchedResultsController.fetchRequest.predicate = nil
        searchBar.resignFirstResponder()
        
        do {
            try fetchedResultsController.performFetch()
            applySnapshot()
        } catch {
            print("検索リセットエラー: \(error)")
        }
    }

    @objc private func clearSearch() {
        searchBar.text = ""
        fetchedResultsController.fetchRequest.predicate = nil
        
        do {
            try fetchedResultsController.performFetch()
            applySnapshot()
        } catch {
            print("検索リセットエラー: \(error)")
        }
    }

    @objc private func toggleSearchBar() {
        searchBar.becomeFirstResponder()   // ← フォーカスしてすぐ入力できる
        showSearchButtons()
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
    
    // MARK: - Setup SearchBar
    private func setupSearchBar() {
        searchBar.placeholder = "検索"
        searchBar.delegate = self
        searchBar.returnKeyType = .search
        navigationItem.titleView = searchBar
    }
    
    // MARK: - Setup TableView
    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.keyboardDismissMode = .interactive
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // DiffableDataSource 設定
        dataSource = UITableViewDiffableDataSource<Int, NSManagedObjectID>(tableView: tableView) { [weak self] tableView, indexPath, objectID in
            guard let self = self else { return UITableViewCell() }
            let note = try? self.viewContext.existingObject(with: objectID) as? Note
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
            
            var config = cell.defaultContentConfiguration()
            config.text = note?.content ?? ""
            config.textProperties.numberOfLines = 1
            cell.contentConfiguration = config
            
            return cell
        }
        
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }
    
    // MARK: - Setup FRC
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
    }
    
    // MARK: - Snapshot適用
    private func applySnapshot(animatingDifferences: Bool = true) {
        var snapshot = NSDiffableDataSourceSnapshot<Int, NSManagedObjectID>()
        snapshot.appendSections([0])
        if let objects = fetchedResultsController.fetchedObjects {
            snapshot.appendItems(objects.map { $0.objectID })
        }
        dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
    }
    
    // MARK: - Add Note
    @objc private func addNote() {
        let editorVC = NoteEditorViewController()
        editorVC.viewContext = viewContext
        editorVC.onSave = { [weak self] in
            // FRC が自動で検知して snapshot 更新
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
            
            var predicateFormat = "content CONTAINS[cd] %@"
            var arguments: [Any] = [keywords[0]]
            for keyword in keywords.dropFirst() {
                predicateFormat += " AND content CONTAINS[cd] %@"
                arguments.append(keyword)
            }
            
            fetchedResultsController.fetchRequest.predicate = NSPredicate(format: predicateFormat, argumentArray: arguments)
        }
        
        do {
            try fetchedResultsController.performFetch()
            applySnapshot()
        } catch {
            print(error)
        }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        searchBar.resignFirstResponder()
    }
    
    // MARK: - Swipe Delete
    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        guard let objectID = dataSource.itemIdentifier(for: indexPath),
              let noteToDelete = try? viewContext.existingObject(with: objectID) as? Note else {
            return nil
        }
        
        let deleteAction = UIContextualAction(style: .destructive, title: "削除") { [weak self] _, _, completionHandler in
            guard let self = self else { return }
            let alert = UIAlertController(title: "確認", message: "このメモを削除しますか？", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel) { _ in
                completionHandler(false)
            })
            alert.addAction(UIAlertAction(title: "削除", style: .destructive) { _ in
                self.viewContext.delete(noteToDelete)
                do { try self.viewContext.save() } catch { print(error) }
                completionHandler(true)
            })
            self.present(alert, animated: true)
        }
        
        let configuration = UISwipeActionsConfiguration(actions: [deleteAction])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }
}

// MARK: - UITableViewDelegate
extension NotesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let objectID = dataSource.itemIdentifier(for: indexPath),
              let note = try? viewContext.existingObject(with: objectID) as? Note else { return }
        let editorVC = NoteEditorViewController()
        editorVC.note = note
        editorVC.viewContext = viewContext
        navigationController?.pushViewController(editorVC, animated: true)
    }
}

// MARK: - NSFetchedResultsControllerDelegate
extension NotesViewController: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        applySnapshot()
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

/*// MARK: - UITableViewDelegate
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

*/
