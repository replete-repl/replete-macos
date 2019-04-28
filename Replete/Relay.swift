//
//  Relay.swift
//
//  Created by Jason Jobe on 5/11/15.
//  Copyright (c) 2015, 2016 Jason Jobe. All rights reserved.
//  https://gist.github.com/wildthink/acfdf82c2625dc73ad6e42d399d91846
//

/* Examle usage
 protocol SomeClassOrProtocol.self) {
 func someClassOrProtocolFunction (some:Int, args:[String])
 }
 relay (SomeClassOrProtocol.self) {
 $0.someClassOrProtocolFunction(some, args)
 }
 relay { (target: SomeClassOrProtocol) in
 target.someClassOrProtocolFunction(some, args)
 }

 protocol Demo {}
 let app = Application.shared

 let demo = app.relay(type: Demo.self)
 let demo2: Demo? = app.relay()
 */

import Foundation

#if os(iOS)
import UIKit.UIResponder
public typealias Responder = UIResponder
public typealias Application = UIApplication
#else
import AppKit.NSResponder
public typealias Responder = NSResponder
public typealias Application = NSApplication
#endif

public protocol AlternateRelay {
    func alternateRelayTarget <T> (type: T.Type, if test: ((T) -> Bool)?) -> T?
}

public extension NSObjectProtocol where Self: Responder
{
    func relay <T> (_ type: T.Type, call: (T) -> Void) -> Void {
        if let target = relayTarget(type: type) { call (target) }
    }

    func relay <T> (_ type: T.Type, if test: (T) -> Bool, call: (T) -> Void) -> Void {
        if let target = relayTarget(type: type) { call (target) }
    }

    func relay<T>() -> T? {
        if let target = relayTarget(type: T.self) { return target }
        return nil
    }

    func alternateRelayTarget <T> (type: T.Type, if test: ((T) -> Bool)?) -> T? {
        return nil
    }

    func relayTarget <T> (type: T.Type, if test: ((T) -> Bool)? = nil) -> T?
    {
        var next: Responder? = self

        while next != nil {
            if let t = next as? T, test?(t) ?? true {
                return t
            }
            if let alt = alternateRelayTarget(type: type, if: test) {
                return alt
            }
            next = next?.nextResponder
        }
//        if let t = Application.shared.delegate as? T, test?(t) ?? true {
//            return t
//        }
//        if let r = Application.shared.delegate as? AlternateRelay,
//            let alt = r.alternateRelayTarget(type: type, if: test) {
//            return alt
//        }
        return nil
    }
}
