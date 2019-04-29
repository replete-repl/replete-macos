//
//  NSExtensions.swift
//  Replete
//
//  Created by Jason Jobe on 4/15/19.
//  Copyright © 2019 Jason Jobe. All rights reserved.
//

import Cocoa

extension NSTextView {

    var fullRange: NSRange {
        return NSRange(location: 0, length: textStorage?.length ?? 0)
    }

    @discardableResult
    func append(_ text: NSAttributedString) -> NSRange? {
        guard let textStorage = textStorage else { return nil }
        let pos = textStorage.length
        textStorage.append(text)
        return NSRange(location: pos, length: text.length)
    }

    @discardableResult
    func append(_ text: String) -> NSRange? {
        return append(NSAttributedString(string: text))
    }
}
