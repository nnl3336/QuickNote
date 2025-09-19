//
//  TranslateViewController.swift
//  QuickNote
//
//  Created by Yuki Sasaki on 2025/09/19.
//

//言語
import UIKit

// MARK: - データ構造
struct Language {
    let name: String
    let code: String
}

struct LanguageSection {
    let title: String
    let languages: [Language]
}

class TranslateViewController: UIViewController {

    // MARK: - 選択中のIndexPath
    private var selectedIndex: IndexPath? {
        didSet {
            guard let indexPath = selectedIndex else { return }
            // 選択した言語コードを保存
            let language = sections[indexPath.section].languages[indexPath.row]
            UserDefaults.standard.set(language.code, forKey: "AppLanguage")
            
            // 即時UI切り替え
            reloadTexts()
        }
    }

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    // 例：切り替え対象のラベル
    private let greetingLabel = UILabel()

    // MARK: - ライフサイクル
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "翻訳"
        view.backgroundColor = .systemBackground

        // TableView
        tableView.dataSource = self
        tableView.delegate = self
        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(tableView)

        // サンプルラベル
        greetingLabel.frame = CGRect(x: 20, y: 400, width: 300, height: 40)
        view.addSubview(greetingLabel)

        // 前回の選択を復元
        if let savedCode = UserDefaults.standard.string(forKey: "AppLanguage") {
            outerLoop: for sectionIndex in 0..<sections.count {
                for rowIndex in 0..<sections[sectionIndex].languages.count {
                    if sections[sectionIndex].languages[rowIndex].code == savedCode {
                        selectedIndex = IndexPath(row: rowIndex, section: sectionIndex)
                        break outerLoop
                    }
                }
            }
        } else {
            // デフォルトは英語
            selectedIndex = IndexPath(row: 1, section: 1) // English
        }
        
        // 初期表示
        reloadTexts()
    }

    // MARK: - ローカライズ用関数
    private func reloadTexts() {
        greetingLabel.text = localizedString("greeting")
    }

    private func localizedString(_ key: String) -> String {
        let code = UserDefaults.standard.string(forKey: "AppLanguage") ?? "en"
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return NSLocalizedString(key, bundle: bundle, comment: "")
        }
        return NSLocalizedString(key, comment: "")
    }
}

// MARK: - UITableView DataSource / Delegate
extension TranslateViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].languages.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        let language = sections[indexPath.section].languages[indexPath.row]
        cell.textLabel?.text = language.name

        // チェックマーク
        if selectedIndex == indexPath {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }

        return cell
    }

    func tableView(_ tableView: UITableView,
                   didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        selectedIndex = indexPath
        tableView.reloadData()
    }
}



// MARK: - セクション分けした言語リスト
private let sections: [LanguageSection] = [
    LanguageSection(title: "アジア", languages: [
        Language(name: "日本語", code: "ja"),
        Language(name: "中文（簡体字）", code: "zh-Hans"),
        Language(name: "中文（繁体字）", code: "zh-Hant"),
        Language(name: "한국어", code: "ko")
    ]),
    LanguageSection(title: "ヨーロッパ", languages: [
        Language(name: "English", code: "en"),
        Language(name: "Français", code: "fr"),
        Language(name: "Deutsch", code: "de")
    ])
]
