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

