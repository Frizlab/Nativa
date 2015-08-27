//
//  Logger.swift
//  Nativa
//
//  Created by Solomenchuk, Vlad on 8/27/15.
//  Copyright © 2015 Aramzamzam LLC. All rights reserved.
//

import Foundation
import Cocoa

public struct Logger {
    public func debug(msg: String) {
        print("debug: \(msg)")
    }
    public func error(msg: String) {
        print("error: \(msg)")

        let center = NSUserNotificationCenter.defaultUserNotificationCenter()
        center.removeAllDeliveredNotifications()
        let note = NSUserNotification()
        note.title = "Error"
        note.informativeText = msg
        center.scheduleNotification(note)
    }
    public func info(msg: String) {
        print("info: \(msg)")
    }
}

public let logger = Logger()
