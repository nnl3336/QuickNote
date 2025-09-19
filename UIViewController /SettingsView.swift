//
//  SettingsView.swift
//  QuickNote
//
//  Created by Yuki Sasaki on 2025/09/19.
//

import UIKit

class SettingsViewController: UITableViewController {
    
    // データ例
    let sectionTitles = ["全体", "テキストエディター", "その他"]
    let items = [
        ["翻訳"],   // セクション0
        ["フォントサイズ", "フォントウェイト"],                   // セクション1
        ["カラーサークル", "バックアップ"]                   // セクション2
    ]
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return sectionTitles.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items[section].count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sectionTitles[section]
    }
    
    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")
            ?? UITableViewCell(style: .default, reuseIdentifier: "cell")
        cell.textLabel?.text = items[indexPath.section][indexPath.row]
        
        // 矢印の有無
        if indexPath.section == 0 {
            cell.accessoryType = .disclosureIndicator
        } else {
            cell.accessoryType = .none
        }
        return cell
    }

    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            tableView.deselectRow(at: indexPath, animated: true)
            
            switch (indexPath.section, indexPath.row) {
            case (0, 0): // 翻訳
                navigationController?.pushViewController(TranslateViewController(), animated: true)
                
            case (1, 0): // フォントサイズ
                navigationController?.pushViewController(FontSizeViewController(), animated: true)
                
            case (1, 1): // フォントウェイト
                navigationController?.pushViewController(FontWeightViewController(), animated: true)
                
            case (2, 0): // カラーサークル
                navigationController?.pushViewController(ColorCircleViewController(), animated: true)
                
            /*case (2, 1): // バックアップ
                navigationController?.pushViewController(BackupViewController(), animated: true)*/
                
            default:
                break
            }
        }

}

// MARK: - AppDelegate または SceneDelegate での起動例
/*class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var coordinator: SettingsCoordinator?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let nav = UINavigationController()
        coordinator = SettingsCoordinator(navigationController: nav)

        let settingsVC = SettingsViewController()
        settingsVC.coordinator = coordinator
        nav.viewControllers = [settingsVC]

        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = nav
        window?.makeKeyAndVisible()

        return true
    }
}
*/

import UIKit





//フォントサイズ
import UIKit

class FontSizeViewController: UITableViewController {
    
    // 選択肢（表示は統一サイズ）
    let fontSizes: [CGFloat] = [12, 14, 16, 18, 20, 24, 28]
    
    // UserDefaults キー
    private let fontSizeKey = "fontSize"
    private let fontWeightKey = "fontWeight"
    
    // 選択中フォントサイズ
    private var selectedFontSize: CGFloat {
        get {
            let saved = UserDefaults.standard.double(forKey: fontSizeKey)
            return saved == 0 ? 16 : CGFloat(saved)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: fontSizeKey)
            updateSampleLabel()
        }
    }
    
    // 選択中フォントウェイト（例: regular, bold）
    private var selectedFontWeight: UIFont.Weight {
        get {
            if let raw = UserDefaults.standard.string(forKey: fontWeightKey),
               let weight = FontWeight(rawValue: raw) {
                return weight.uiFontWeight
            }
            return .regular
        }
        set {
            UserDefaults.standard.set(FontWeight.from(weight: newValue).rawValue, forKey: fontWeightKey)
            updateSampleLabel()
        }
    }
    
    // サンプル表示用ラベル
    private let sampleLabel: UILabel = {
        let label = UILabel()
        label.text = "サンプルテキスト Aaあア"
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "フォントサイズ"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        
        setupFooterView()
        updateSampleLabel()
    }
    
    private func setupFooterView() {
        let footer = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 120))
        footer.addSubview(sampleLabel)
        
        NSLayoutConstraint.activate([
            sampleLabel.centerXAnchor.constraint(equalTo: footer.centerXAnchor),
            sampleLabel.centerYAnchor.constraint(equalTo: footer.centerYAnchor),
            sampleLabel.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 16),
            sampleLabel.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -16)
        ])
        
        tableView.tableFooterView = footer
    }
    
    private func updateSampleLabel() {
        sampleLabel.font = UIFont.systemFont(ofSize: selectedFontSize, weight: selectedFontWeight)
    }
    
    // MARK: - Table
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fontSizes.count
    }
    
    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let size = fontSizes[indexPath.row]
        
        cell.textLabel?.text = "\(Int(size)) pt"
        cell.textLabel?.font = UIFont.systemFont(ofSize: 17) // 一律表示
        
        // チェックマーク
        cell.accessoryType = (size == selectedFontSize) ? .checkmark : .none
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedFontSize = fontSizes[indexPath.row]
        tableView.reloadData()
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - FontWeight ヘルパー
enum FontWeight: String {
    case regular, medium, semibold, bold
    
    var uiFontWeight: UIFont.Weight {
        switch self {
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        }
    }
    
    var displayName: String {
        switch self {
        case .regular: return "Regular"
        case .medium: return "Medium"
        case .semibold: return "Semibold"
        case .bold: return "Bold"
        }
    }
    
    static func from(weight: UIFont.Weight) -> FontWeight {
        switch weight {
        case .bold: return .bold
        case .semibold: return .semibold
        case .medium: return .medium
        default: return .regular
        }
    }
}


class FontWeightViewController: UITableViewController {
    
    // 一覧に出すフォントウェイト
    let fontWeights: [FontWeight] = [.regular, .medium, .semibold, .bold]
    
    // UserDefaults キー
    private let fontSizeKey = "fontSize"
    private let fontWeightKey = "fontWeight"
    
    // 保存されているフォントサイズ
    private var selectedFontSize: CGFloat {
        let saved = UserDefaults.standard.double(forKey: fontSizeKey)
        return saved == 0 ? 16 : CGFloat(saved)
    }
    
    // 保存されているフォントウェイト
    private var selectedFontWeight: FontWeight {
        get {
            if let raw = UserDefaults.standard.string(forKey: fontWeightKey),
               let weight = FontWeight(rawValue: raw) {
                return weight
            }
            return .regular
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: fontWeightKey)
            updateSampleLabel()
        }
    }
    
    // サンプル表示用ラベル
    private let sampleLabel: UILabel = {
        let label = UILabel()
        label.text = "サンプルテキスト Aaあア"
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "フォントウェイト"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        
        setupFooterView()
        updateSampleLabel()
    }
    
    private func setupFooterView() {
        let footer = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 120))
        footer.addSubview(sampleLabel)
        
        NSLayoutConstraint.activate([
            sampleLabel.centerXAnchor.constraint(equalTo: footer.centerXAnchor),
            sampleLabel.centerYAnchor.constraint(equalTo: footer.centerYAnchor),
            sampleLabel.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 16),
            sampleLabel.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -16)
        ])
        
        tableView.tableFooterView = footer
    }
    
    private func updateSampleLabel() {
        sampleLabel.font = UIFont.systemFont(ofSize: selectedFontSize,
                                             weight: selectedFontWeight.uiFontWeight)
    }
    
    // MARK: - Table
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fontWeights.count
    }
    
    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let weight = fontWeights[indexPath.row]
        
        cell.textLabel?.text = weight.displayName
        cell.textLabel?.font = UIFont.systemFont(ofSize: 17, weight: weight.uiFontWeight)
        
        // チェックマーク
        cell.accessoryType = (weight == selectedFontWeight) ? .checkmark : .none
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedFontWeight = fontWeights[indexPath.row]
        tableView.reloadData()
        tableView.deselectRow(at: indexPath, animated: true)
    }
}


class ColorCircleViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "カラーサークル"
        view.backgroundColor = .systemBackground
    }
}

import UIKit
import UniformTypeIdentifiers
/*
//バックアップ
class BackupViewController: UIViewController {
    
    private let backupButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("iPhoneのファイルにバックアップ", for: .normal)
        return button
    }()
    
    private let restoreButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("ファイルからダウンロードして保存", for: .normal)
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        let stack = UIStackView(arrangedSubviews: [backupButton, restoreButton])
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40)
        ])
        
        //backupButton.addTarget(self, action: #selector(exportBackup), for: .touchUpInside)
        restoreButton.addTarget(self, action: #selector(importBackup), for: .touchUpInside)
        
        // --- クルクル (一度だけ作る) ---
                indicator = UIActivityIndicatorView(style: .large)
                indicator.center = view.center
                indicator.hidesWhenStopped = true
                view.addSubview(indicator)
                
                // --- 進捗バー (一度だけ作る) ---
                progressView = UIProgressView(progressViewStyle: .default)
                progressView.frame = CGRect(x: 40, y: 200, width: 300, height: 20)
                progressView.progress = 0.0
                progressView.isHidden = true // 最初は隠す
                view.addSubview(progressView)
    }
    
    private var indicator: UIActivityIndicatorView!
    private var progressView: UIProgressView!

    // --- バックアップ ---
    /*@objc private func exportBackup() {
            // 表示して開始
            indicator.startAnimating()
            progressView.isHidden = false
            progressView.setProgress(0.0, animated: false)
            
            DispatchQueue.global(qos: .userInitiated).async {
                // 重い処理 (例: CoreData → JSON)
                let backupData = BackupData(items: [], folders: [])
                let encoder = JSONEncoder()
                let data = try? encoder.encode(backupData)
                
                // ダミー進捗
                for i in 1...10 {
                    Thread.sleep(forTimeInterval: 0.2)
                    DispatchQueue.main.async {
                        self.progressView.setProgress(Float(i) / 10.0, animated: true)
                    }
                }
                
                DispatchQueue.main.async {
                    // 完了したら消す
                    self.indicator.stopAnimating()      // hidesWhenStopped = true なので自動で非表示
                    self.progressView.isHidden = true   // バーも隠す
                    
                    // 終わったらファイル書き出し
                    if let data = data {
                        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("backup.json")
                        try? data.write(to: tmpURL)
                        let picker = UIDocumentPickerViewController(forExporting: [tmpURL])
                        picker.delegate = self
                        self.present(picker, animated: true)
                    }
                }
            }
        }*/
    

    // --- 復元 ---
    @objc private func importBackup() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json])
        picker.delegate = self
        present(picker, animated: true)
    }
}
*/
/*extension BackupViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        
        if controller.documentPickerMode == .open {
            // --- 復元処理 ---
            do {
                let data = try Data(contentsOf: url)
                let decoded = try JSONDecoder().decode(BackupData.self, from: data)
                restoreToCoreData(decoded)
            } catch {
                print("復元失敗: \(error)")
            }
        } else if controller.documentPickerMode == .exportToService {
            print("バックアップ保存成功: \(urls)")
        }
    }
    
    private func restoreToCoreData(_ decoded: BackupData) {
        // CoreData に保存する処理をここに実装
        print("復元データ: items=\(decoded.items.count), folders=\(decoded.folders.count)")
    }
}
*/
