//
//  UICollectionView .swift
//  QuickNote
//
//  Created by Yuki Sasaki on 2025/08/28.
//

import SwiftUI
import CoreData
import Combine

class NotesViewController: UIViewController, UISearchBarDelegate, NSFetchedResultsControllerDelegate, UITableViewDelegate, UITableViewDataSource, FilterViewControllerDelegate  {
    func filterViewController(_ vc: FilterViewController, didUpdate filter: CurrentFilter) {
        
    }
    
    func filter(
        //_ vc: FilterViewController,
        searchText: String,
        isLiked: Bool,
        checkState: CheckState,
        isContainsImage: Bool,
        state: FilterState
    ) {
        print("delegate filterViewController呼び出し")
        // デバッグ用に受け取った値を確認
        print("searchText: \(searchText), isLiked: \(isLiked), checkState: \(checkState), isContainsImage: \(isContainsImage), state: \(state)")
        
        self.filterState = state
        
        
        // searchfetch に渡す
        searchfetch(
            searchText: searchText,
            isLiked: isLiked,
            checkState: checkState,
            isContainsImage: isContainsImage,
            state: filterState       // ← FilterState に応じたフィルタ
        )
        
        self.currentFilter = CurrentFilter(searchText: searchText, isLiked: isLiked, checkState: checkState, isContainsImage: isContainsImage)
    }
    
    
    
    weak var filterdelegate: FilterViewControllerDelegate?

    
    var filterState: FilterState = .all

    
    
    var viewContext: NSManagedObjectContext!
    
    private var fetchedResultsController: NSFetchedResultsController<Note>!
    
    let tableView = UITableView()
    let searchBar = UISearchBar()
    
    // Floating buttons
    let addButton = UIButton(type: .system)
    let searchButton = UIButton(type: .system)
    let cancelButton = UIButton(type: .system)
    let clearButton = UIButton(type: .system)
    let buttonStack = UIStackView()
    
    // メニュー幅
    // MARK: - Menu layout
    //private let menuWidth: CGFloat = 280
    private var menuWidth: CGFloat {
        min(UIScreen.main.bounds.width * 0.8, 400) // 最大 400pt
    }
    // 開閉状態
    //var isOpen = false
    // 外側のオーバーレイ（黒背景）
    /*        weak var overlayView: UIView?*/
    
    //private let overlayView = UIView()
    private var overlayView: UIView!
    
    //    var flatData: [Item] = []
    
    
    // 選択中のノートを管理
    var selectedItems: Set<Note> = []
    
    private var isCheck = false
    private var isNotCheck = false
    private var isContainsImage = false
    
    
    
    //***
    
    // MARK: - ViewController Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // MARK: - View 基本設定
        view.backgroundColor = .systemBackground
        title = "メモ一覧"
        
        // MARK: - FetchedResultsController セットアップ
        searchfetch()
        
        // MARK: - TableView セットアップ
        setupTableView()
        
        // MARK: - その他 UI
        setupNormalModeNavigationBar()
        setupFloatingButton()
    }
    
    
    
    //***
    
    
    
    
    
    
    private func duplicate(note: Note) {
        let newNote = Note(context: viewContext)
        newNote.content = note.content
        newNote.date = Date() // 現在日時にする
        do {
            try viewContext.save()
        } catch {
            print("複製エラー: \(error)")
        }
    }
    
    // MARK: - Context Menu（長押しで複製）コンテキ　.contextMenu　コンテキストメニュー
    func tableView(_ tableView: UITableView,
                   contextMenuConfigurationForRowAt indexPath: IndexPath,
                   point: CGPoint) -> UIContextMenuConfiguration? {
        
        let configuration = UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            // 複製アクション
            let duplicateAction = UIAction(title: "複製", image: UIImage(systemName: "doc.on.doc")) { [weak self] _ in
                guard let self = self else { return }
                let note = self.fetchedResultsController.object(at: indexPath)
                self.duplicate(note: note)
            }
            
            // 選択アクション
            let selectAction = UIAction(title: "選択", image: UIImage(systemName: "checkmark.circle")) { [weak self] _ in
                guard let self = self else { return }
                let note = self.fetchedResultsController.object(at: indexPath)
                
                self.selectedItems.insert(note)
                
                // セルを更新して青くする
                tableView.reloadRows(at: [indexPath], with: .none)
                
                updateNavigationBar(for: .selection(selectedCount: selectedItems.count))
            }
            
            
            
            return UIMenu(title: "", children: [duplicateAction, selectAction])
        }
        
        return configuration
    }
    
    // 選択を切り替える処理を追加
    private func toggleSelection(at indexPath: IndexPath, in tableView: UITableView) {
        let item = fetchedResultsController.object(at: indexPath)
        
        if selectedItems.contains(item) {
            selectedItems.remove(item)
        } else {
            selectedItems.insert(item)
        }
        
        // セルのUIを更新
        tableView.reloadRows(at: [indexPath], with: .none)
        
        print("現在の selectedItems: \(self.selectedItems.map { $0.content ?? "" })")
        
        // 選択数に応じてモード切り替え
        if selectedItems.isEmpty {
            updateNavigationBar(for: .normal)
        } else {
            updateNavigationBar(for: .selection(selectedCount: selectedItems.count))
        }
    }
    
    
    
    
    // MARK: - セルタップ
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // 選択中のアイテムがある場合は、遷移せず選択切り替えモードにする
        if !selectedItems.isEmpty {
            toggleSelection(at: indexPath, in: tableView)
            return
        }
        
        // 選択中が空の場合のみ遷移
        let item = fetchedResultsController.object(at: indexPath)
        
        let editorVC = NoteEditorViewController()
        editorVC.viewContext = viewContext
        editorVC.note = item
        //editorVC.filterState = FilterStateStore.shared.filterState
        
        editorVC.onSave = { [weak self] in
            self?.tableView.reloadRows(at: [indexPath], with: .automatic)
        }
        
        navigationController?.pushViewController(editorVC, animated: true)
    }
    
    
    
    
    private var menuLeadingConstraint: NSLayoutConstraint!
    private var isMenuOpen = false
    
    private let menuContainer = UIView()
    
    // MARK: - メニュー開閉アニメーション
    // メニューを開閉し、背景の暗幕もアニメーションで表示
    private func animateMenu(open: Bool) {
        guard let navView = navigationController?.view else { return }
        isMenuOpen = open
        menuLeadingConstraint.constant = open ? 0 : -menuWidth
        overlayView.isUserInteractionEnabled = open
        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut]) {
            self.overlayView.alpha = open ? 1 : 0
            navView.layoutIfNeeded()
        }
    }
    
    
    
    // MARK: - TransferModal モーダル
    /*func openTransferModal() {
     // 先に閉じる
     animateMenu(open: false)
     
     let cVC = TransferModal(context: self.viewContext, selectedFolders: selectedFolders)
     
     // シートとして出す
     if let sheet = cVC.sheetPresentationController {
     sheet.detents = [
     //.medium(),
     .large()
     ]
     sheet.prefersGrabberVisible = true
     sheet.preferredCornerRadius = 20
     
     // ← 最初に .large() を選んで表示する
     sheet.selectedDetentIdentifier = .large
     }
     
     present(cVC, animated: true)
     }*/
    
    
    
    // MARK: - ジェスチャー処理
    // エッジスワイプとオーバーレイタップを処理
    @objc private func handleEdgePan(_ gesture: UIScreenEdgePanGestureRecognizer) {
        guard let navView = navigationController?.view else { return }
        let translation = gesture.translation(in: navView)
        let progress = min(max(translation.x / menuWidth, 0), 1)
        
        switch gesture.state {
        case .changed:
            // メニューの位置をスワイプ量に応じて更新
            menuLeadingConstraint.constant = -menuWidth + menuWidth * progress
            overlayView.alpha = progress
        case .ended, .cancelled:
            // 50%以上スワイプしたら開く、それ以外は閉じる
            let shouldOpen = progress > 0.5
            animateMenu(open: shouldOpen)
        default:
            break
        }
    }
    
    
    @objc private func handleTapOutside(_ gesture: UITapGestureRecognizer) {
        animateMenu(open: false)
    }
    
    
    // MARK: - メニューボタン
    // ボタンでメニューの開閉を切り替え
    @objc private func menuButtonTapped() {
        animateMenu(open: !isMenuOpen)
    }
    
    
    // MARK: - SearchBar　ナビゲーションバー
    enum NavBarMode {
        case normal
        case selection(selectedCount: Int)
    }
    
    func updateNavigationBar(for mode: NavBarMode) {
        switch mode {
        case .normal:
            // ノーマルモードに切り替え
            setupNormalModeNavigationBar()
            
        case .selection(let selectedCount):
            // 選択モードに切り替え（選択数0の初期状態）
            setupSelectionModeNavigationBar()
        }
    }
    // ノーマルモード
    func setupNormalModeNavigationBar() {
        // タイトル
        navigationItem.titleView = nil
        navigationItem.title = "Notes"
        
        // 左ボタン：メニュー
        let menuButton = UIBarButtonItem(
            image: UIImage(systemName: "line.horizontal.3"),
            style: .plain,
            target: self,
            action: #selector(menuButtonTapped)
        )
        navigationItem.leftBarButtonItem = menuButton
        
        // 右ボタン：フォルダ + 設定
        /*let folderButton = UIBarButtonItem(
            image: UIImage(systemName: "folder"),
            style: .plain,
            target: self,
            action: #selector(folderButtonTapped)
        )*/
        
        let settingsButton = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: self,
            action: #selector(settingsButtonTapped)
        )
        navigationItem.rightBarButtonItems = [settingsButton/*, folderButton*/]
    }
    
    // 選択モード
    func setupSelectionModeNavigationBar() {
        // タイトルに選択数などを表示
        navigationItem.titleView = nil
        navigationItem.title = "選択中 (0)" // 選択数に応じて更新
        
        // 左ボタン：キャンセル
        let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel,
                                           target: self,
                                           action: #selector(cancelSelection))
        navigationItem.leftBarButtonItem = cancelButton
        
        // 右ボタン：削除や移動など
        /*let deleteButton = UIBarButtonItem(barButtonSystemItem: .trash,
         target: self,
         action: #selector(deleteSelected))*/
    }
    
    @objc func cancelSelection() {
        // 選択を解除してノーマルモードに戻す
        deselectAllItems()
        setupNormalModeNavigationBar()
        
        tableView.reloadData()
    }
    func deselectAllItems() {
        print("選択セルを削除")
        self.selectedItems.removeAll()
    }
    
    // MARK: - ルートフォルダ追加
    
    // MARK: - フォルダ一覧を取得してテーブル更新
    /*private func reloadFolders() {
     let request: NSFetchRequest<Folder> = Folder.fetchRequest()
     request.sortDescriptors = [NSSortDescriptor(key: "folderName", ascending: true)]
     do {
     let folders = try viewContext.fetch(request)
     // ここでテーブル表示用に変換する
     // NotesViewController では階層不要なのでそのまま flatData に格納
     flatData = folders
     tableView.reloadData()
     } catch {
     print("フォルダ取得失敗: \(error)")
     }
     }*/
    
    
    // MARK: - ルートフォルダ追加
    /*@objc func folderButtonTapped() {
     presentTextFieldAlert(title: "ルートフォルダ名を入力",
     placeholder: "新しいフォルダ名") { [weak self] folderName in
     guard let self = self else { return }
     let newFolder = Folder(context: self.viewContext)
     newFolder.folderName = folderName
     newFolder.isOpen = false
     newFolder.parent = nil
     
     do {
     try self.viewContext.save()
     self.performFetchAndReload()
     } catch {
     print("保存失敗: \(error)")
     }
     }
     }*/
    
    /*
     func performFetchAndReload() {
     do {
     try fetchedResultsController.performFetch()
     if let roots = fetchedResultsController.fetchedObjects {
     flatData = flatten(roots)
     tableView.reloadData()
     }
     } catch {
     print("FRC fetch error: \(error)")
     }
     }
     
     // MARK: - 階層をフラット化（展開状態を考慮）
     func flatten(_ items: [Item]) -> [Item] {
     var result: [Item] = []
     for item in items {
     result.append(item)
     if item.isOpen,
     let children = item.children?.allObjects as? [Item] {
     result.append(contentsOf: flatten(children))
     }
     }
     return result
     }*/
    
    //設定ボタン
    @objc private func settingsButtonTapped() {
        print("設定ボタンタップ")
        
        let settingsVC = SettingsViewController() // 自作VC
        let nav = UINavigationController(rootViewController: settingsVC)
        nav.modalPresentationStyle = .formSheet // ← UINavigationController に設定する
        present(nav, animated: true)
    }
    
    
    
    //検索ボタン
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        showSearchButtons()
    }
    //検索バー
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        // 入力に応じて CoreData を検索してテーブルを更新
        if searchText.isEmpty {
            fetchedResultsController.fetchRequest.predicate = nil
        } else {
            let keywords = searchText.components(separatedBy: " ").filter { !$0.isEmpty }
            guard !keywords.isEmpty else { return }
            var predicateFormat = "text CONTAINS[cd] %@"
            var arguments: [Any] = [keywords[0]]
            for keyword in keywords.dropFirst() {
                predicateFormat += " AND text CONTAINS[cd] %@"
                arguments.append(keyword)
            }
            fetchedResultsController.fetchRequest.predicate = NSPredicate(format: predicateFormat, argumentArray: arguments)
        }
        do {
            try fetchedResultsController.performFetch()
            tableView.reloadData()
        } catch { print(error) }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        // 検索ボタン押下でキーボードを閉じる
        searchBar.resignFirstResponder()
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // スクロール開始時にキーボードを閉じる
        searchBar.resignFirstResponder()
    }
    
    
    // MARK: - TableView　セットアップUITableView
    private func setupTableView() {
        guard let frc = fetchedResultsController else {
            print("fetchedResultsController is nil!")
            return
        }
        
        if let items = frc.fetchedObjects {
            print("Fetched Items count:", items.count)
            for item in items {
                print("Item text:", item.content ?? "(nil)")
            }
        } else {
            print("fetchedObjects is nil")
        }
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.keyboardDismissMode = .interactive
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    //セル個数
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchedResultsController.fetchedObjects?.count ?? 0
    }
    //セル表示
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let note = fetchedResultsController.object(at: indexPath)
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        let fullText = note.content ?? ""

        if note.isContainsImage {
            cell.textLabel?.text = "📷 画像"
        } else {
            let lines = fullText.components(separatedBy: .newlines)
            if let firstNonEmptyLine = lines.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                cell.textLabel?.text = firstNonEmptyLine
            } else {
                cell.textLabel?.text = "(無題)"
            }
        }



        // 選択中かどうかで色を変える
        if selectedItems.contains(note) {
            cell.backgroundColor = UIColor.systemBlue//.withAlphaComponent(0.3)
            cell.textLabel?.textColor = .label   // ← 黒/白 自動対応
        } else {
            cell.backgroundColor = .clear
            cell.textLabel?.textColor = .label
        }
        
        
        return cell
    }
    
    
    //スワイプアクション
    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "削除") { [weak self] _, _, completionHandler in
            guard let self = self else { return }
            let alert = UIAlertController(title: "確認", message: "このメモを削除しますか？", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel) { _ in completionHandler(false) })
            alert.addAction(UIAlertAction(title: "削除", style: .destructive) { _ in
                let noteToDelete = self.fetchedResultsController.object(at: indexPath)
                self.viewContext.delete(noteToDelete)
                try? self.viewContext.save()
                completionHandler(true)
            })
            self.present(alert, animated: true)
        }
        let config = UISwipeActionsConfiguration(actions: [deleteAction])
        config.performsFirstActionWithFullSwipe = false
        return config
    }
    
    
    
    // MARK: - FRC　検索
    // NSFetchedResultsController のセットアップとテーブルビュー更新処理
    func searchfetch(
        searchText: String = "",
        isLiked: Bool = false,
        checkState: CheckState = .none,
        isContainsImage: Bool = false,
        state: FilterState = .all
    ) {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        
        // ソートは日付順
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.date, ascending: false)]
        request.fetchBatchSize = 20
        
        var predicates: [NSPredicate] = []
        
        // テキスト検索
        if !searchText.isEmpty {
            predicates.append(NSPredicate(format: "content CONTAINS[cd] %@", searchText))
        }
        
        // お気に入り
        if isLiked {
            predicates.append(NSPredicate(format: "isLiked == true"))
        }
        
        // CheckState
        switch checkState {
        case .checked:
            predicates.append(NSPredicate(format: "isCheck == true"))
        case .notChecked:
            predicates.append(NSPredicate(format: "isCheck == false"))
        case .none:
            break
        }
        
        // 画像あり
        if isContainsImage {
            predicates.append(NSPredicate(format: "isContainsImage != nil OR isContainsImage == false"))
        }
        
        // FilterState
        switch state {
        case .all:
            // nil を除外して false のものを取得
            predicates.append(NSPredicate(format: "isDust == nil OR isDust == false"))
        case .memo:
            predicates.append(NSPredicate(format: "folder == nil"))
        case .folder(let folder):
            if let folder = folder {
                predicates.append(NSPredicate(format: "folder == %@", folder))
            } else {
                predicates.append(NSPredicate(format: "folder == nil"))
            }
        case .trash:
            predicates.append(NSPredicate(format: "isDust == true"))
        }
        
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: viewContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        fetchedResultsController.delegate = self
        
        if let results = try? viewContext.fetch(request) {
            print("[DEBUG] fetch results count: \(results.count)")
        }
        
        try? fetchedResultsController.performFetch()
        tableView.reloadData()
    }
    
    
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
        // データ変更に応じてテーブル行を追加・削除・更新・移動
        switch type {
        case .insert:
            if let newIndexPath = newIndexPath { tableView.insertRows(at: [newIndexPath], with: .automatic) }
        case .delete:
            if let indexPath = indexPath { tableView.deleteRows(at: [indexPath], with: .automatic) }
        case .update:
            if let indexPath = indexPath { tableView.reloadRows(at: [indexPath], with: .automatic) }
        case .move:
            if let indexPath = indexPath, let newIndexPath = newIndexPath { tableView.moveRow(at: indexPath, to: newIndexPath) }
        @unknown default: break
        }
    }
    
    
    // MARK: - Floating Buttons　セットアップボタン
    // 画面右下のフローティングボタンのセットアップと表示切替
    private func setupFloatingButton() {
        // 各ボタン初期化
        [addButton, searchButton, cancelButton, clearButton].forEach {
            $0.layer.cornerRadius = 28
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        addButton.setImage(UIImage(systemName: "plus"), for: .normal)
        addButton.tintColor = .white
        addButton.backgroundColor = .systemBlue
        addButton.addTarget(self, action: #selector(addNote), for: .touchUpInside)
        
        searchButton.setImage(UIImage(systemName: "magnifyingglass"), for: .normal)
        searchButton.tintColor = .white
        searchButton.backgroundColor = .systemBlue
        searchButton.addTarget(self, action: #selector(toggleSearchBar), for: .touchUpInside)
        
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.backgroundColor = .systemRed
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelSearch), for: .touchUpInside)
        
        clearButton.setTitle("Clear", for: .normal)
        clearButton.backgroundColor = .systemGray
        clearButton.setTitleColor(.white, for: .normal)
        clearButton.addTarget(self, action: #selector(clearSearch), for: .touchUpInside)
        
        buttonStack.axis = .horizontal
        buttonStack.spacing = 16
        buttonStack.alignment = .center
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.addArrangedSubview(searchButton)
        buttonStack.addArrangedSubview(addButton)
        view.addSubview(buttonStack)
        
        NSLayoutConstraint.activate([
            addButton.widthAnchor.constraint(equalToConstant: 56),
            addButton.heightAnchor.constraint(equalToConstant: 56),
            searchButton.widthAnchor.constraint(equalToConstant: 56),
            searchButton.heightAnchor.constraint(equalToConstant: 56),
            
            cancelButton.widthAnchor.constraint(equalToConstant: 56),
            cancelButton.heightAnchor.constraint(equalToConstant: 56),
            clearButton.widthAnchor.constraint(equalToConstant: 56),
            clearButton.heightAnchor.constraint(equalToConstant: 56),
            
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            buttonStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }
    
    func showNormalButtons() {
        buttonStack.arrangedSubviews.forEach { $0.isHidden = false }
        cancelButton.isHidden = true
        clearButton.isHidden = true
    }
    
    func showSearchButtons() {
        buttonStack.arrangedSubviews.forEach { $0.isHidden = true }
        cancelButton.isHidden = false
        clearButton.isHidden = false
        buttonStack.arrangedSubviews.forEach { buttonStack.removeArrangedSubview($0) }
        buttonStack.addArrangedSubview(clearButton)
        buttonStack.addArrangedSubview(cancelButton)
        
        // 絞り込みモーダルを出す
        presentFilterModal()
    }
    
    private func presentFilterModal() {
        let filterVC = FilterViewController()
        filterVC.modalPresentationStyle = .overCurrentContext // iPadならモーダル風、iPhoneなら全画面
        filterVC.filterdelegate = self // 結果を受け取るならdelegateにする
        //filterVC.filterState = self.filterState
        //filterVC.currentFilter = currentFilter  // ← nil じゃないことを保証
        filterVC.currentFilter = currentFilter  // ← nil じゃないことを保証
        present(filterVC, animated: true)
    }
    
    var currentFilter: CurrentFilter = .initial

    @objc private func cancelSearch() {
        searchBar.text = ""
        fetchedResultsController.fetchRequest.predicate = nil
        searchBar.resignFirstResponder()
        buttonStack.arrangedSubviews.forEach { buttonStack.removeArrangedSubview($0); $0.removeFromSuperview() }
        buttonStack.addArrangedSubview(searchButton)
        buttonStack.addArrangedSubview(addButton)
        showNormalButtons()
        try? fetchedResultsController.performFetch()
        tableView.reloadData()
    }
    
    @objc private func clearSearch() {
        searchBar.text = ""
        fetchedResultsController.fetchRequest.predicate = nil
        try? fetchedResultsController.performFetch()
        tableView.reloadData()
    }
    
    //虫眼鏡ボタン　検索
    @objc private func toggleSearchBar() {
        //print("新しい検索条件: \(currentFilter)")
        
        searchBar.becomeFirstResponder()
        //showSearchButtons()
        
        presentFilterModal()
    }
    
    
    // MARK: - Add Note
    // ノート追加ボタンの処理
    @objc private func addNote() {
        let editorVC = NoteEditorViewController()
        editorVC.viewContext = viewContext
        editorVC.filterState = self.filterState   // ← ここで渡す
        navigationController?.pushViewController(editorVC, animated: true)
    }
}


// 共有フィルター管理
class CurrentFilterStore {
    static let shared = CurrentFilterStore()
    private init() {}

    var currentFilter: CurrentFilter = .initial
}
