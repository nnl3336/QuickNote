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
    let searchButton = UIButton(type: .system)
    let cancelButton = UIButton(type: .system)
    let clearButton = UIButton(type: .system)

    private func setupFloatingButton() {
        // ＋ボタン
        let addButton = UIButton(type: .system)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.setImage(UIImage(systemName: "plus"), for: .normal)
        addButton.tintColor = .white
        addButton.backgroundColor = view.tintColor
        addButton.layer.cornerRadius = 28
        addButton.layer.shadowColor = UIColor.black.cgColor
        addButton.layer.shadowOpacity = 0.3
        addButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        addButton.layer.shadowRadius = 4
        addButton.addTarget(self, action: #selector(addNote), for: .touchUpInside)
        view.addSubview(addButton)

        // 🔍ボタン
        searchButton.translatesAutoresizingMaskIntoConstraints = false
        searchButton.setImage(UIImage(systemName: "magnifyingglass"), for: .normal)
        searchButton.tintColor = .white
        searchButton.backgroundColor = .systemBlue
        searchButton.layer.cornerRadius = 28
        searchButton.layer.shadowColor = UIColor.black.cgColor
        searchButton.layer.shadowOpacity = 0.3
        searchButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        searchButton.layer.shadowRadius = 4
        searchButton.addTarget(self, action: #selector(toggleSearchBar), for: .touchUpInside)
        view.addSubview(searchButton)

        // Cancel ボタン
        setupActionButton(cancelButton, systemName: "xmark", color: .systemRed, action: #selector(cancelSearch))
        cancelButton.isHidden = true

        // Clear ボタン
        setupActionButton(clearButton, systemName: "trash", color: .systemGray, action: #selector(clearSearch))
        clearButton.isHidden = true

        NSLayoutConstraint.activate([
            // 通常表示
            addButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            addButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            addButton.widthAnchor.constraint(equalToConstant: 56),
            addButton.heightAnchor.constraint(equalToConstant: 56),

            searchButton.trailingAnchor.constraint(equalTo: addButton.leadingAnchor, constant: -16),
            searchButton.bottomAnchor.constraint(equalTo: addButton.bottomAnchor),
            searchButton.widthAnchor.constraint(equalToConstant: 56),
            searchButton.heightAnchor.constraint(equalToConstant: 56),

            // 検索表示
            clearButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            clearButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            clearButton.widthAnchor.constraint(equalToConstant: 56),
            clearButton.heightAnchor.constraint(equalToConstant: 56),

            cancelButton.trailingAnchor.constraint(equalTo: clearButton.leadingAnchor, constant: -16),
            cancelButton.bottomAnchor.constraint(equalTo: clearButton.bottomAnchor),
            cancelButton.widthAnchor.constraint(equalToConstant: 56),
            cancelButton.heightAnchor.constraint(equalToConstant: 56)
        ])
    }

    private func setupActionButton(_ button: UIButton, systemName: String, color: UIColor, action: Selector) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: systemName), for: .normal)
        button.tintColor = .white
        button.backgroundColor = color
        button.layer.cornerRadius = 28
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.3
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.addTarget(self, action: action, for: .touchUpInside)
        view.addSubview(button)
    }

    @objc private func showSearchButtons() {
        searchButton.isHidden = true
        cancelButton.isHidden = false
        clearButton.isHidden = false

        NSLayoutConstraint.activate([
            clearButton.widthAnchor.constraint(equalToConstant: 56),
            clearButton.heightAnchor.constraint(equalToConstant: 56),
            clearButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            clearButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),

            cancelButton.widthAnchor.constraint(equalToConstant: 56),
            cancelButton.heightAnchor.constraint(equalToConstant: 56),
            cancelButton.trailingAnchor.constraint(equalTo: clearButton.leadingAnchor, constant: -16),
            cancelButton.bottomAnchor.constraint(equalTo: clearButton.bottomAnchor)
        ])
    }

    @objc private func cancelSearch() {
        searchBar.text = ""              // 入力を全消し
        fetchedResultsController.fetchRequest.predicate = nil // 検索条件をリセット
        // 検索バー閉じる
        searchBar.resignFirstResponder()

        cancelButton.isHidden = true
        clearButton.isHidden = true
        searchButton.isHidden = false
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

