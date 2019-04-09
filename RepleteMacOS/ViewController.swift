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
        outputTextView?.append("\n")
        outputTextView?.append(text)
        if let count = outputTextView?.textStorage?.length, count > 2 {
            outputTextView?.scrollRangeToVisible(NSRange(location: count - 1, length: 1))
        }
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
    func append(_ text: String) {
        textStorage?.append(NSAttributedString(string: text))
    }
}
