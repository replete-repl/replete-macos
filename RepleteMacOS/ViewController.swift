//
//  ViewController.swift
//  RepleteMacOS
//
//  Created by Jason Jobe on 4/8/19.
//  Copyright © 2019 Jason Jobe. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

    @IBOutlet var inputTextView: NSTextView?
    @IBOutlet var outputTextView: NSTextView?

    var history: [NSRange] = []
    var historyIndex: Int = -1 {
        didSet {
//            let cnt = history.count - 1
            if historyIndex >= history.count { historyIndex = history.count - 1 }
            if historyIndex <= 0 { historyIndex = history.isEmpty ? -1 : 0 }
        }
    }

    var ctx = CSContext()

    override func viewDidLoad() {

        super.viewDidLoad()
        configure(textView: inputTextView)
        configure(textView: outputTextView)

        inputTextView?.delegate = self
        outputTextView?.delegate = self

        let tap = NSClickGestureRecognizer(target: self, action: #selector(clicked(_:)))
        outputTextView?.addGestureRecognizer(tap)

        ctx.setPrintCallback { (incoming: Bool, message: String!) -> Void in
            DispatchQueue.main.async {
                self.loadMessage(incoming, text: message)
            }
        }

        DispatchQueue.main.async {
            let version = self.ctx.getClojureScriptVersion()
            let masthead = """
            ClojureScript \(version)
                Docs: (doc function-name)
                      (find-doc \"part-of-name\")
              Source: (source function-name)
             Results: Stored in *1, *2, *3,
                      an exception in *e
            --------------------------------------

            """
            self.loadMessage(false, text: masthead)
        };

        NSLog("Initializing...");
        DispatchQueue.global(qos: .background).async {
            self.ctx.initializeJavaScriptEnvironment()
            DispatchQueue.main.async {
                // mark ready
                NSLog("Ready");
            }
        }

    }

    @objc func clicked(_ sender: NSClickGestureRecognizer) {
        if (sender.view as? NSTextView) == outputTextView {
            let pt = sender.location(in: outputTextView)
            guard let loc = outputTextView?.characterIndexForInsertion(at: pt) else { return }
            if let h_ndx = history.firstIndex (where: { $0.contains(loc) }) {
                historyIndex = h_ndx
                refresh()
            }
        }
    }

    func configure(textView: NSTextView?) {
        guard let textView = textView else { return }
        textView.font = NSFont(name: "Menlo", size: 12);
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.enabledTextCheckingTypes = 0
    }

}

extension ViewController {

    func loadMessage(_ incoming: Bool, isInput: Bool = false, text: String) {
        guard let outputTextView = outputTextView,
            !text.isEmpty, let s = prepareMessageForDisplay(isInput, text: text) else { return }

        if let rng = outputTextView.append(s) {
            if isInput {
                history.append(rng)
                historyIndex = history.count - 1
            }
            outputTextView.setSelectedRange(NSRange(location: 0, length: 0))
        }
        if incoming { outputTextView.append("\n") }

        if let count = outputTextView.textStorage?.length, count > 2 {
            outputTextView.scrollRangeToVisible(NSRange(location: count - 1, length: 1))
        }
    }

    func prepareMessageForDisplay(_  isInput: Bool, text: String) -> NSMutableAttributedString? {
        if (text != "\n") {
            let s = NSMutableAttributedString(string:text);
            while (markString(s)) {};
            s.addAttribute(NSAttributedString.Key.font,
                           value: NSFont(name: "Menlo", size: 12) as Any,
                           range: NSMakeRange(0, s.length));
            
            // Spacing between input and output
            
            let paragraphStyle = NSMutableParagraphStyle()
            if (isInput) {
                paragraphStyle.paragraphSpacingBefore = 10.0
            } else {
                paragraphStyle.paragraphSpacingBefore = 5.0
            }
            s.addAttribute(NSAttributedString.Key.paragraphStyle,
                           value: paragraphStyle as Any,
                           range: NSMakeRange(0, s.length));
            
            // Make the color of input gray
            
            if (isInput) {
                s.addAttribute(NSAttributedString.Key.foregroundColor,
                               value: NSColor.gray as Any,
                               range: NSMakeRange(0, s.length));
            }
            
            return s
        }
        return nil
    }

    func markString(_ s: NSMutableAttributedString) -> Bool {
        if (s.string.contains("\u{001b}[")) {

            let text = s.string;
            let range : Range<String.Index> = text.range(of: "\u{001b}[")!;
            let index: Int = text.distance(from: text.startIndex, to: range.lowerBound);
            let index2 = text.index(text.startIndex, offsetBy: index + 2);
            var color : NSColor = NSColor.black;
            if (text[index2...].hasPrefix("34m")){
                color = NSColor.blue;
            } else if (text[index2...].hasPrefix("32m")){
                color = NSColor(red: 0.0, green: 0.75, blue: 0.0, alpha: 1.0);
            } else if (text[index2...].hasPrefix("35m")){
                color = NSColor(red: 0.75, green: 0.0, blue: 0.75, alpha: 1.0);
            } else if (text[index2...].hasPrefix("31m")){
                color = NSColor(red: 1, green: 0.33, blue: 0.33, alpha: 1.0);
            }

            s.replaceCharacters(in: NSMakeRange(index, 5), with: "");
            s.addAttribute(NSAttributedString.Key.foregroundColor,
                           value: color,
                           range: NSMakeRange(index, s.length-index));
            return true;
        }

        return false;
    }

    func refresh() {
        // Highlight bg of currenty History block
        // Update input w/ selected History block
        guard let inputTextView = inputTextView, let outputTextView = outputTextView else { return }
        if let rng = selectedHistoryRange, let ts = outputTextView.textStorage {
            outputTextView.setSelectedRange(rng)
            let str = ts.attributedSubstring(from: rng)
            inputTextView.insertText(str, replacementRange: inputTextView.fullRange)
        }
    }

    var selectedHistoryRange: NSRange? {
        guard !history.isEmpty, historyIndex >= 0 else { return nil }
        return history[historyIndex]
    }

    @IBAction
    func moveBackInHistory(_ sender: Any?) {
        historyIndex -= 1
        refresh()
    }

    @IBAction
    func moveForwardInHistory(_ sender: Any?) {
        historyIndex += 1
        refresh()
    }

    @IBAction
    func evaluate (_ sender: Any) {
        guard let cmd = inputTextView?.string, !cmd.isEmpty else { return }
        loadMessage(true, isInput: true, text: cmd)
        ctx.evaluate(cmd)
    }
}

extension ViewController: NSTextViewDelegate {

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(evaluate(_:)):
            self.evaluate(textView)
            return true
        default:
            return false
        }
    }
}

//////////////

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
