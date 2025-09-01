//
//  extension.swift
//  QuickNote
//
//  Created by Yuki Sasaki on 2025/08/25.
//

import SwiftUI

extension NSMutableAttributedString {
    static func withLinkDetection(from attrText: NSMutableAttributedString) -> NSMutableAttributedString {
        let text = attrText.string
        let types: NSTextCheckingResult.CheckingType = .link

        if let detector = try? NSDataDetector(types: types.rawValue) {
            let matches = detector.matches(in: text, range: NSRange(location: 0, length: text.utf16.count))
            for match in matches {
                if let url = match.url {
                    attrText.addAttribute(.link, value: url, range: match.range)
                }
            }
        }
        return attrText
    }
}


/*
extension NSMutableAttributedString {
    static func withLinkDetection(from string: String) -> NSMutableAttributedString {
        let attributed = NSMutableAttributedString(string: string)
        
        // http/https を正規表現で検出
        let pattern = "(https?://[a-zA-Z0-9./?=_-]+)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let matches = regex.matches(in: string, range: NSRange(string.startIndex..., in: string))
            for match in matches {
                let url = (string as NSString).substring(with: match.range)
                attributed.addAttribute(.link, value: url, range: match.range)
            }
        }
        
        // 文字色などデフォルト属性
        attributed.addAttribute(.foregroundColor,
                                value: UIColor.label,
                                range: NSRange(location: 0, length: attributed.length))
        return attributed
    }
}
*/
