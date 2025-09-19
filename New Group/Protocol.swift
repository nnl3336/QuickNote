//
//  Protocol.swift
//  QuickNote
//
//  Created by Yuki Sasaki on 2025/09/19.
//

import SwiftUI

//TransferModal
protocol FolderSelectionDelegate: AnyObject {
    //func transferModalDidFinish(_ modal: TransferModal)

    func folderDidChange(for note: Note)
}



enum CheckState {
    case none       // どちらでもない
    case checked    // チェック済み
    case notChecked // 未チェック
}

var checkState: CheckState = .none

enum FilterState {
    case all       // すべて（isDust == nil）
    case memo      // 親なし（parent == nil）
    case folder(Folder?) // 特定のフォルダ（parent == selectedFolder）
    case trash     // ゴミ箱（isDust == true）
}

//検索
protocol FilterViewControllerDelegate: AnyObject {
    func filterViewController(_ vc: FilterViewController, didUpdate filter: CurrentFilter)

    func filter(
        //_ vc: FilterViewController,
        searchText: String,
        isLiked: Bool,
        checkState: CheckState,      // 既存
        isContainsImage: Bool,
        state: FilterState           // ← 新しく追加
    )
}



//SlideMenu
protocol SlideMenuDelegate: AnyObject {
    var filterState: FilterState { get set }

    func slideMenu(/*_ menu: SlideMenuViewController, */didSelectFolders folders: Set<Folder>)
    /*func didUpdateSelectedFolders(_ folders: /*[Folder]*/ Set<Folder>) // ←追加*/

    func didToggleBool_TransferModal(_ value: Bool) // true で C を出す
}
