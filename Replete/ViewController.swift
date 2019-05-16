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
    var enterPressed = false;
    var initialized = false;

    var ctx = CSContext()

    override func viewDidLoad() {

        super.viewDidLoad()
        configure(textView: inputTextView)
        configure(textView: outputTextView)

        inputTextView?.delegate = self
        outputTextView?.delegate = self

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

            """
            self.loadMessage(false, isMasthead: true, text: masthead)
        };

        NSLog("Initializing...");
        DispatchQueue.global(qos: .background).async {
            self.ctx.initializeJavaScriptEnvironment()
            DispatchQueue.main.async {
                // mark ready
                NSLog("Ready");
                self.initialized = true;
            }
        }

    }

    override func viewDidAppear() {
        super.viewDidAppear()
        inputTextView?.window?.makeFirstResponder(inputTextView)
    }
    
    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        
        if (replacementString == "\n") {
            enterPressed = true;
        }
        
        // Automatically evaluate if enter happens to be pressed when
        // cursor is positioned at the end of the text.
        if (enterPressed && affectedCharRange.location == textView.string.count) {
            enterPressed = false
            self.evaluate(textView)
            return false;
        }
        
        return true;
    }
    
    func runParinfer() {
        
        let currentText = inputTextView!.string
        let currentSelectedRange = inputTextView!.selectedRange
        
        if (currentText != "") {
            
            let result: Array = ctx.parinferFormat(currentText, pos:Int32(currentSelectedRange.location), enterPressed:enterPressed)
            inputTextView!.string = result[0] as! String
            inputTextView!.selectedRange = NSMakeRange(result[1] as! Int, 0)
        }
        enterPressed = false;
    }
    
    // This is a native profile of Parinfer, meant for use when
    // ClojureScript hasn't yet initialized, but yet the user
    // is already typing. It covers extremely simple cases that
    // could be typed immediately.
    func runPoorMansParinfer() {
        
        let currentText = inputTextView!.string
        let currentSelectedRange = inputTextView!.selectedRange
        
        if (currentText != "") {
            if (currentSelectedRange.location == 1) {
                if (currentText == "(") {
                    inputTextView!.string = "()";
                } else if (currentText == "[") {
                    inputTextView!.string = "[]";
                } else if (currentText == "{") {
                    inputTextView!.string = "{}";
                }
                inputTextView!.selectedRange = currentSelectedRange;
            }
            
        }
    }
    
    func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return }
        if (textView == inputTextView) {
            if (initialized) {
                runParinfer()
            } else {
                runPoorMansParinfer()
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

    func loadMessage(_ incoming: Bool, isInput: Bool = false, isMasthead: Bool = false, text: String) {
        guard let outputTextView = outputTextView,
            !text.isEmpty, let s = prepareMessageForDisplay(isInput, isMasthead: isMasthead, text: text)
            else { return }

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

    func prepareMessageForDisplay(_  isInput: Bool, isMasthead: Bool, text: String) -> NSMutableAttributedString? {
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
                           range: NSMakeRange(0, 1));
            
            // Make the color of input and masthead gray
            
            if (isInput || isMasthead) {
                s.addAttribute(NSAttributedString.Key.foregroundColor,
                               value: NSColor.darkGray as Any,
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
            outputTextView.scrollRangeToVisible(rng)
            let str = ts.attributedSubstring(from: rng).string
            inputTextView.insertText(str, replacementRange: inputTextView.fullRange)
        }
    }

    var selectedHistoryRange: NSRange? {
        guard !history.isEmpty, historyIndex >= 0 else { return nil }
        return history[historyIndex]
    }

    var terminalWidth: Int32 {
        let charWidth = NSFont(name: "Menlo", size: 12)!.maximumAdvancement.width
        let viewWidth = self.outputTextView!.textContainer!.size.width;
        // We subtract 2 to fudge down a little
        return Int32(viewWidth / charWidth - 2)
    }
    
    @IBAction
    func moveBackInHistory(_ sender: Any?) {
        refresh()
        historyIndex -= 1
    }

    @IBAction
    func moveForwardInHistory(_ sender: Any?) {
        historyIndex += 1
        refresh()
    }

    @IBAction
    func evaluate (_ sender: Any) {
        guard let cmd = inputTextView?.string.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
              !cmd.isEmpty else { return }
        loadMessage(true, isInput: true, text: cmd)
        ctx.setWidth(self.terminalWidth);
        ctx.evaluate(cmd)
        inputTextView?.string = "";
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
