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

    var ctx = CSContext()

    override func viewDidLoad() {
        super.viewDidLoad()

        inputTextView?.font = NSFont(name: "Menlo", size: 12);
        
        inputTextView?.delegate = self
        outputTextView?.delegate = self

        ctx.setPrintCallback { (incoming: Bool, message: String!) -> Void in
            DispatchQueue.main.async {
                self.loadMessage(incoming, text: message)
            }
        }

        DispatchQueue.main.async {
            let version = self.ctx.getClojureScriptVersion()
            let masthead = "\nClojureScript \(version)\n" +
                "    Docs: (doc function-name)\n" +
                "          (find-doc \"part-of-name\")\n" +
                "  Source: (source function-name)\n" +
                " Results: Stored in *1, *2, *3,\n" +
            "          an exception in *e\n";
            self.loadMessage(false, text: masthead)
        };

        NSLog("Initializing...");
        DispatchQueue.global(qos: .background).async {
            self.ctx.initializeJavaScriptEnvironment()
            DispatchQueue.main.async {
                // mark ready
                NSLog("Ready");
//                self.initialized = true;
//                let hasText = self.textView.hasText
//                self.evalButton.isEnabled = hasText
//                if (hasText) {
//                    self.runParinfer()
//                }
            }
        }

    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
}

extension ViewController {

    func loadMessage(_ incoming: Bool, text: String) {
        guard let s = prepareMessageForDisplay(text) else { return }

        outputTextView?.append("\n")
        outputTextView?.append(s)
        if let count = outputTextView?.textStorage?.length, count > 2 {
            outputTextView?.scrollRangeToVisible(NSRange(location: count - 1, length: 1))
        }
    }

    func prepareMessageForDisplay(_ text: String) -> NSMutableAttributedString? {
        if (text != "\n") {
            let s = NSMutableAttributedString(string:text);
            while (markString(s)) {};
            s.addAttribute(NSAttributedString.Key.font,
                           value: NSFont(name: "Menlo", size: 12),
                           range: NSMakeRange(0, s.length));
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

    @IBAction
    func evaluate (_ sender: Any) {
        guard let cmd = inputTextView?.string, !cmd.isEmpty else { return }
        loadMessage(false, text: cmd)
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
    func append(_ text: NSAttributedString) {
        textStorage?.append(text)
    }
    func append(_ text: String) {
        textStorage?.append(NSAttributedString(string: text))
    }
}
