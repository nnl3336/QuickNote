//
//  extension.swift
//  QuickNote
//
//  Created by Yuki Sasaki on 2025/08/25.
//

import SwiftUI


extension NSMutableAttributedString {
    func surroundLinksWithSpaces(normalColor: UIColor, font: UIFont) {
        // リンクを探す
        enumerateAttribute(.link, in: NSRange(location: 0, length: length)) { value, range, _ in
            if value != nil {
                // すでにスペースが入っているかチェック
                let beforeRange = NSRange(location: range.location, length: 1)
                let afterRange = NSRange(location: range.location + range.length - 1, length: 1)

                var needsBefore = true
                var needsAfter = true

                if beforeRange.location > 0,
                   (string as NSString).substring(with: beforeRange) == "\u{200B}" { // ゼロ幅スペース
                    needsBefore = false
                }
                if afterRange.location + afterRange.length < length,
                   (string as NSString).substring(with: afterRange) == "\u{200B}" {
                    needsAfter = false
                }

                // 前にゼロ幅スペースを追加
                if needsBefore {
                    insert(NSAttributedString(string: "\u{200B}", attributes: [
                        .font: font,
                        .foregroundColor: normalColor
                    ]), at: range.location)
                }

                // 後にゼロ幅スペースを追加
                if needsAfter {
                    insert(NSAttributedString(string: "\u{200B}", attributes: [
                        .font: font,
                        .foregroundColor: normalColor
                    ]), at: range.location + range.length + (needsBefore ? 1 : 0))
                }
            }
        }
    }
}


// MARK: - 戻っても真っ黒
/*extension NSMutableAttributedString {
    func surroundLinksWithSpaces(normalColor: UIColor, font: UIFont) {
        // 後ろから処理して範囲がずれないようにする
        var linkRanges: [NSRange] = []
        
        self.enumerateAttribute(.link, in: NSRange(location: 0, length: self.length)) { value, range, _ in
            if value != nil {
                linkRanges.append(range)
            }
        }
        
        // 後ろから挿入
        for range in linkRanges.reversed() {
            // 後ろにスペース追加
            self.insert(NSAttributedString(string: " ", attributes: [.foregroundColor: normalColor, .font: font]), at: range.location + range.length)
            // 前にスペース追加
            self.insert(NSAttributedString(string: " ", attributes: [.foregroundColor: normalColor, .font: font]), at: range.location)
        }
    }
}
*/


// MARK: - NSMutableAttributedString Extension
extension NSMutableAttributedString {
    static func withLinkDetection(from attributedString: NSMutableAttributedString) -> NSMutableAttributedString {
        let result = NSMutableAttributedString(attributedString: attributedString)
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return result
        }

        let textRange = NSRange(location: 0, length: result.string.utf16.count)
        detector.enumerateMatches(in: result.string, options: [], range: textRange) { match, _, _ in
            guard let match = match, let url = match.url else { return }
            result.addAttribute(.link, value: url, range: match.range)
        }
        return result
    }
}

// MARK: - 真っ黒だけど、戻れば良い
/*extension NSMutableAttributedString {
    func surroundLinksWithSpaces(normalColor: UIColor, font: UIFont) {
        // リンクを探す
        enumerateAttribute(.link, in: NSRange(location: 0, length: length)) { value, range, _ in
            if value != nil {
                // すでにスペースが入っているかチェック
                let beforeRange = NSRange(location: range.location, length: 1)
                let afterRange = NSRange(location: range.location + range.length - 1, length: 1)

                var needsBefore = true
                var needsAfter = true

                if beforeRange.location > 0,
                   (string as NSString).substring(with: beforeRange) == "\u{200B}" { // ゼロ幅スペース
                    needsBefore = false
                }
                if afterRange.location + afterRange.length < length,
                   (string as NSString).substring(with: afterRange) == "\u{200B}" {
                    needsAfter = false
                }

                // 前にゼロ幅スペースを追加
                if needsBefore {
                    insert(NSAttributedString(string: "\u{200B}", attributes: [
                        .font: font,
                        .foregroundColor: normalColor
                    ]), at: range.location)
                }

                // 後にゼロ幅スペースを追加
                if needsAfter {
                    insert(NSAttributedString(string: "\u{200B}", attributes: [
                        .font: font,
                        .foregroundColor: normalColor
                    ]), at: range.location + range.length + (needsBefore ? 1 : 0))
                }
            }
        }
    }
}*/
 

/*
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
 */


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
