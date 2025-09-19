//
//  FilterView.swift
//  QuickNote
//
//  Created by Yuki Sasaki on 2025/09/19.
//

import SwiftUI
import UIKit
import CoreData

class FilterViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {

    weak var filterdelegate: FilterViewControllerDelegate?
    
    let searchButton = UIButton(type: .system)
    let cancelButton = UIButton(type: .system)
    let clearButton = UIButton(type: .system)
    let buttonStack = UIStackView()
    
    //***
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "検索"
        label.font = .boldSystemFont(ofSize: 20)
        label.textAlignment = .center
        return label
    }()
    
    private let searchField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "キーワードを入力"
        tf.borderStyle = .roundedRect
        return tf
    }()
    
    private let tableView = UITableView(frame: .zero, style: .plain)
    
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("閉じる", for: .normal)
        return button
    }()
    
    // 条件
    /*private var searchTextTemp: String = "a"
    private var isLikedTemp: Bool = false
    private var checkStateTemp: CheckState = .none
    private var isContainsImageTemp: Bool = false*/
    
    private let items = ["いいね済み", "チェック済み", "未チェック", "画像あり"]

    
    var currentFilter: CurrentFilter!    // 親から渡す

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        searchField.becomeFirstResponder()
        
        view.addSubview(containerView)
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 300),
            containerView.heightAnchor.constraint(equalToConstant: 420)
        ])
        
        // StackView で縦に配置
        let stack = UIStackView(arrangedSubviews: [titleLabel, searchField, tableView, closeButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20)
        ])
        
        // tableView 設定
        tableView.delegate = self
        tableView.dataSource = self
        tableView.isScrollEnabled = false
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        
        searchField.addTarget(self, action: #selector(searchFieldChanged(_:)), for: .editingChanged)
        
        closeButton.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)
        
        setupFloatingButton()
        
        // 親から渡された値を一時プロパティにコピー　値入れ
        /*searchTextTemp = currentFilter.searchText
        isLikedTemp = currentFilter.isLiked
        checkStateTemp = currentFilter.checkState
        isContainsImageTemp = currentFilter.isContainsImage*/
        
        searchField.text = currentFilter.searchText
        print("viewDidLoad searchTextTemp: \(currentFilter.searchText)")
    }
    
    

    
    // MARK: - ボタン
    private func setupFloatingButton() {
        // 共通スタイルを先にまとめて設定
        // 2. 共通スタイル
        [searchButton, clearButton, cancelButton].forEach {
            $0.layer.cornerRadius = 28
            $0.clipsToBounds = true   // ← 角丸が効くように必須
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        // 3. 個別設定
        let searchButton = UIButton(type: .system) // system ボタンでもOKb
        searchButton.setTitle("Ok", for: .normal)
        searchButton.setTitleColor(.white, for: .normal) // 白文字に変更
        searchButton.backgroundColor = .systemBlue
        searchButton.layer.cornerRadius = 28
        searchButton.clipsToBounds = true
        searchButton.addTarget(self, action: #selector(search), for: .touchUpInside)


        cancelButton.backgroundColor = .systemRed
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelSearch), for: .touchUpInside)

        clearButton.backgroundColor = .systemGray
        clearButton.setTitle("Clear", for: .normal)
        clearButton.setTitleColor(.white, for: .normal)
        clearButton.addTarget(self, action: #selector(clearSearch), for: .touchUpInside)

        // 4. StackView に追加
        buttonStack.axis = .horizontal
        buttonStack.spacing = 16
        buttonStack.alignment = .center
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        [searchButton, clearButton, cancelButton,].forEach { buttonStack.addArrangedSubview($0) }
        view.addSubview(buttonStack)

        // 5. 固定サイズ制約
        [searchButton, clearButton, cancelButton].forEach {
            $0.widthAnchor.constraint(equalToConstant: 56).isActive = true
            $0.heightAnchor.constraint(equalToConstant: 56).isActive = true
        }

        // 6. stack の位置制約
        NSLayoutConstraint.activate([
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            buttonStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }
    //キャンセル
    @objc private func cancelSearch() {
        searchField.text = ""
        
        // 初期化したいタイミングで
        currentFilter = CurrentFilter.initial
        
        // 元に戻す条件は delegate に任せる
        filterdelegate?.filter(
            //self,
            searchText: currentFilter.searchText,
            isLiked: currentFilter.isLiked,
            checkState: currentFilter.checkState,
            isContainsImage: currentFilter.isContainsImage,
            state: self.filterState       // ← ここを追加
        )
        
        //currentFilter.checkState = .none
        //checkState = .none
        // delegate に通知
        filterdelegate?.filterViewController(self, didUpdate: currentFilter)

        
        searchField.resignFirstResponder()
        buttonStack.arrangedSubviews.forEach { buttonStack.removeArrangedSubview($0); $0.removeFromSuperview() }
        
        dismiss(animated: true)
    }
    
    

    //クリア
    @objc private func clearSearch() {
        searchField.text = ""
        /*filterdelegate?.filter(
            //self,
            searchText: "",
            isLiked: false,
            checkState: .none,
            isContainsImage: false,
            state: self.filterState        // ← ここを追加
        )*/
        currentFilter.searchText = ""
        
        filterdelegate?.filter(
            //self,
            searchText: currentFilter.searchText,
            isLiked: currentFilter.isLiked,
            checkState: currentFilter.checkState,
            isContainsImage: currentFilter.isContainsImage,
            state: self.filterState       // ← ここを追加
        )
        // delegate に通知
        filterdelegate?.filterViewController(self, didUpdate: currentFilter)
        
        //print("searchTextTemp: \(searchTextTemp)")
        
        //dismiss(animated: true)
        
    }
    //サーチボタン okb
    //サーチボタン ok
    @objc private func search() {
        //searchTextTemp = currentFilter.searchText
        
        // 閉じる直前に UITextField の値を取得
        //searchTextTemp = searchField.text ?? ""
        /*print("searchTextTemp: \(searchTextTemp)")
        print("searchField.text: \(searchField.text)")*/

        // 一時プロパティを currentFilter に反映
        /*currentFilter.searchText = searchField.text ?? ""
        currentFilter.isLiked = isLikedTemp
        currentFilter.checkState = checkStateTemp
        currentFilter.isContainsImage = isContainsImageTemp*/
        
        filterdelegate?.filter(
            //self,
            searchText: currentFilter.searchText,
            isLiked: currentFilter.isLiked,
            checkState: currentFilter.checkState,
            isContainsImage: currentFilter.isContainsImage,
            state: self.filterState       // ← ここを追加
        )

        // delegate に通知
        filterdelegate?.filterViewController(self, didUpdate: currentFilter)

        // モーダルを閉じる
        dismiss(animated: true)
    }


    
    
    @objc private func dismissSelf() {
        dismiss(animated: true)
    }
    
    //エンター押すたび
    @objc private func searchFieldChanged(_ textField: UITextField) {
        currentFilter.searchText = searchField.text ?? "a"
        notifyDelegate()
    }
    
    // Enterキー（Returnキー）が押されたときに呼ばれる　エンター押したとき
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder() // キーボードを閉じる
        notifyDelegate()                  // delegate に通知
        dismiss(animated: true, completion: nil) // モーダルを閉じる
        return true
    }
    
    
    
    var filterState: FilterState = .all
    
    
    private func notifyDelegate() {
        //let searchText = searchField.text ?? ""
        //let searchText = searchField.text ?? ""
        filterdelegate?.filter(
            //self,
            searchText: currentFilter.searchText/*searchField.text ?? "a"*/,   // ← UITextField の値を渡す
            isLiked: currentFilter.isLiked,              // ← TableView で選択した値を渡す
            checkState: currentFilter.checkState,        // ← TableView で選択した値を渡す
            isContainsImage: currentFilter.isContainsImage, // ← TableView で選択した値を渡す
            state: filterState      // ← FilterState を選択できる場合はそれを渡す
        )
    }

    
    // MARK: - TableView
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    //セル表示
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = items[indexPath.row]
        cell.selectionStyle = .none
        
        switch indexPath.row {
        case 0: cell.accessoryType = currentFilter.isLiked ? .checkmark : .none
        case 1: cell.accessoryType = (currentFilter.checkState == .checked) ? .checkmark : .none
        case 2: cell.accessoryType = (currentFilter.checkState == .notChecked) ? .checkmark : .none
        case 3: cell.accessoryType = currentFilter.isContainsImage ? .checkmark : .none
        default: break
        }
        return cell
    }
    
    
    

    //セルタップ
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.row {
        case 0:
            currentFilter.isLiked.toggle()
            tableView.reloadRows(at: [indexPath], with: .automatic)
        case 1:
            currentFilter.checkState = (currentFilter.checkState == .checked) ? .none : .checked
            tableView.reloadRows(at: [IndexPath(row: 1, section: 0),
                                      IndexPath(row: 2, section: 0)], with: .automatic)
        case 2:
            currentFilter.checkState = (currentFilter.checkState == .notChecked) ? .none : .notChecked
            tableView.reloadRows(at: [IndexPath(row: 1, section: 0),
                                      IndexPath(row: 2, section: 0)], with: .automatic)
        case 3:
            currentFilter.isContainsImage.toggle()
            tableView.reloadRows(at: [indexPath], with: .automatic)
        default:
            break
        }

        notifyDelegate()
    }

}

// 共通の struct
struct CurrentFilter {
    var searchText: String
    var isLiked: Bool
    var checkState: CheckState
    var isContainsImage: Bool

    static var initial = CurrentFilter(
        searchText: "",
        isLiked: false,
        checkState: .none,
        isContainsImage: false
    )
}
