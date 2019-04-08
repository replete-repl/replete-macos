//
//  AppDelegate.swift
//  Relete-OSX
//
//  Created by Jason Jobe on 4/7/19.
//  Copyright © 2019 Jason Jobe. All rights reserved.
//

import Cocoa
import JavaScriptCore

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var csContext = CSContext()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
//        self.rootDirectory = [[AppDelegate applicationDocumentsDirectory] absoluteString];
//        set_root_directory([self.rootDirectory cStringUsingEncoding:NSUTF8StringEncoding] + 7);
//
//        self.caRootPath = [[NSBundle mainBundle] pathForResource:@"cacert" ofType:@"pem"];
//        set_ca_root_path([self.caRootPath cStringUsingEncoding:NSUTF8StringEncoding]);

    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

//public var ctx: JSGlobalContextRef = JSGlobalContextRef()
