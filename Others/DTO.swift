//
//  DTO.swift
//  QuickNote
//
//  Created by Yuki Sasaki on 2025/09/19.
//

import SwiftUI

// 複合Entity
/*struct BackupData: Codable {
    /*var histories: [HistoryDTO]
    var photos: [PhotoDTO]*/
    var items: [ItemDTO]
    var folders: [FolderDTO]
}*/

/*struct ItemDTO: Codable {
    var text: String?
    var timestamp: Date?
    var id: UUID?
    var folderID: UUID?  // Folderとの関連を保持したい場合

    init(from item: Item) {
        self.text = item.text
        self.timestamp = item.timestamp
        self.id = item.id
        self.folderID = item.folder?.id
    }
}*/

/*struct FolderDTO: Codable {
    var folderName: String?
    var id: UUID?

    init(from folder: Folder) {
        self.folderName = folder.folderName
        self.id = folder.id
    }
}*/


/*struct PhotoDTO: Codable {
    let id: UUID?
    let photoCaption: String?
    let photoMakeDate: Date?
    let photoPicture: String? // Base64エンコード
    
    var itemID: UUID?

    init(from photo: Photo) {
        id = photo.id ?? UUID()
        photoCaption = photo.photoCaption
        photoMakeDate = photo.photoMakeDate
        photoPicture = photo.photoPicture?.base64EncodedString()
        
        itemID = photo.item?.id
    }
}*/

/*struct PhotoDTO: Codable {
    var id: UUID
    var photoCaption: String?
    var photoMakeDate: Date?
    var photoPicture: Data?
    var itemID: UUID?
}*/


/*struct HistoryDTO: Codable {
    let id: UUID?
    let historyDate: Date?
    let historyText: String?
    
    var itemID: UUID?

    init(from history: History) {
        id = history.id ?? UUID()
        historyDate = history.historyDate
        historyText = history.historyText
        
        itemID = history.item?.id
    }
}*/

/*struct HistoryDTO: Codable {
    var id: UUID
    var historyDate: Date?
    var historyText: String?
    var itemID: UUID?
}*/


/*struct FolderDTO: Codable {
    let id: UUID?
    let currentDate: Date?
    let folderMadeTime: Date?
    let folderName: String?
    let isHide: Bool
    let sortIndex: Int64
    let isOpen: Bool
    
    let parentFolderID: UUID?
    //let items: [ItemDTO]


    init(from folder: Folder) {
        id = folder.id ?? UUID()
        currentDate = folder.currentDate
        folderMadeTime = folder.folderMadeTime
        folderName = folder.folderName
        isHide = folder.isHide
        sortIndex = folder.sortIndex
        isOpen = folder.isOpen
        
        parentFolderID = folder.parent?.id
        
        //items = folder.items?.compactMap { ($0 as? Item)?.toItemDTO() } ?? []
        
        // items プロパティを適切に初期化
        //items = folder.items?.compactMap { ItemDTO(item: $0 as! Item) } ?? []

        /*
         items = folder.items.map { ItemDTO(item: $0) }  // ItemDTO に変換して格納
         */
    }

}*/

/*struct FolderDTO: Codable {
    var id: UUID
    var folderName: String?
    var currentDate: Date?
    var folderMadeTime: Date?
    var isHide: Bool
    var sortIndex: Int16
    var isOpen: Bool
    
    // 親Folderや子FolderのIDを持っておく場合
    var parentID: UUID?
    var childrenIDs: [UUID]?
    var secondFolderIDs: [UUID]?
}*/

/*struct ItemDTO: Codable {
    let id: UUID?
    let dustDate: Date?
    let editDate: Date?
    let isBlue: Bool
    let isCheck: Bool
    let isDust: Bool
    let isGreen: Bool
    let isLiked: Bool
    let isPink: Bool
    let isRed: Bool
    let isYellow: Bool
    let makeDate: Date?
    let text: String?
    let timestamp: Date?
    //let folderID: UUID?
    let mutable: Data?  // Base64 ではなく Data 型に変更
    //let attributedContent: String? // Base64エンコード
    //let imageFirst: String? // Base64エンコード
    let containsImage: Bool
    let colorName: String?
    
    var folderID: UUID?  // Folderとの関連を保持したい場合
    
    /*let photos: [PhotoDTO]
    let histories: [HistoryDTO]*/


    init(from item: Item) {
        id = item.id ?? UUID()
        dustDate = item.dustDate
        editDate = item.editDate
        isBlue = item.isBlue
        isCheck = item.isCheck
        isDust = item.isDust
        isGreen = item.isGreen
        isLiked = item.isLiked
        isPink = item.isPink
        isRed = item.isRed
        isYellow = item.isYellow
        makeDate = item.makeDate
        text = item.text
        timestamp = item.timestamp
//        folderID = item.folder?.id
        
        // Data化して保存
        if let attributed = item.mutable {
            mutable = attributed
        } else {
            mutable = nil
        }
        
        //attributedContent = item.attributedContent?.base64EncodedString()
        //imageFirst = item.image_first?.base64EncodedString()
        containsImage = item.isContainsImage
        colorName = item.colorName
        
        folderID = item.folder?.id

        /*photos = item.photos?.compactMap { ($0 as? Photo)?.toPhotoDTO() } ?? []
        histories = item.histories?.compactMap { ($0 as? History)?.toHistoryDTO() } ?? []*/

        // photos と histories の初期化をオプショナルの扱いに合わせて修正
        /*photos = item.photos?.compactMap { $0 != nil ? PhotoDTO(photo: $0!) : nil } ?? []*/
        /*histories = item.histories?.compactMap { $0 != nil ? HistoryDTO(history: $0!) : nil } ?? []*/

        /*// Ensure that photos and histories are initialized properly
        photos = item.photos.map { PhotoDTO(photo: $0) } // Assuming you have an initializer for PhotoDTO
        histories = item.histories.map { HistoryDTO(history: $0) } // Assuming you have an initializer for HistoryDTO*/
    }
    
    func decodedAttributedString() -> NSMutableAttributedString? {
        guard let base64 = mutable,
              let data = Data(base64Encoded: base64) else { return nil }

        return try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? NSMutableAttributedString
    }
    // デコード用ヘルパー（Data → NSMutableAttributedString）
    /*func decodedAttributedString() -> NSMutableAttributedString? {
        guard let data = attributedContent else { return nil }
        do {
            return try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? NSMutableAttributedString
        } catch {
            print("Failed to decode attributed string:", error)
            return nil
        }
    }*/
}*/

/*struct ItemDTO: Codable {
    var id: UUID
    var timestamp: Date?
    var dustDate: Date?
    var editDate: Date?
    var isBlue: Bool
    var isCheck: Bool
    var isDust: Bool
    var isGreen: Bool
    var isLiked: Bool
    var isPink: Bool
    var isRed: Bool
    var isYellow: Bool
    var makeDate: Date?
    var text: String?
    var colorName: String?
    var containsImage: Bool
    var attributedContent: Data?
    var image_first: Data?
    var folderID: UUID?
    
    // histories を追加
    var histories: [History]? // 例: String の配列、実際の型は適切に変更

    enum CodingKeys: String, CodingKey {
        case id, timestamp, dustDate, editDate, isBlue, isCheck, isDust, isGreen, isLiked, isPink, isRed, isYellow, makeDate, text, colorName, containsImage, attributedContent, image_first, folderID, histories
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try? container.decode(Date.self, forKey: .timestamp)
        dustDate = try? container.decode(Date.self, forKey: .dustDate)
        editDate = try? container.decode(Date.self, forKey: .editDate)
        isBlue = (try? container.decode(Bool.self, forKey: .isBlue)) ?? false
        isCheck = (try? container.decode(Bool.self, forKey: .isCheck)) ?? false
        isDust = (try? container.decode(Bool.self, forKey: .isDust)) ?? false
        isGreen = (try? container.decode(Bool.self, forKey: .isGreen)) ?? false
        isLiked = (try? container.decode(Bool.self, forKey: .isLiked)) ?? false
        isPink = (try? container.decode(Bool.self, forKey: .isPink)) ?? false
        isRed = (try? container.decode(Bool.self, forKey: .isRed)) ?? false
        isYellow = (try? container.decode(Bool.self, forKey: .isYellow)) ?? false
        containsImage = (try? container.decode(Bool.self, forKey: .containsImage)) ?? false
        histories = try? container.decode([History].self, forKey: .histories) // histories のデコード
        text = try container.decodeIfPresent(String.self, forKey: .text)
        colorName = try container.decodeIfPresent(String.self, forKey: .colorName)
        attributedContent = try container.decodeIfPresent(Data.self, forKey: .attributedContent)
        image_first = try container.decodeIfPresent(Data.self, forKey: .image_first)
        folderID = try container.decodeIfPresent(UUID.self, forKey: .folderID)

        if let timestamp = try? container.decode(Double.self, forKey: .makeDate) {
            makeDate = Date(timeIntervalSince1970: timestamp)
        } else if let dateString = try? container.decode(String.self, forKey: .makeDate) {
            let formatter = ISO8601DateFormatter()
            makeDate = formatter.date(from: dateString)
        } else {
            makeDate = nil
        }
    }
}
*/


/*
struct DTO: View {
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}

#Preview {
    DTO()
}
*/
