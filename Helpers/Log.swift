//
//  Log.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 01.07.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import Foundation
import SwiftyBeaver

struct Log
{
    enum LoggerType {
        case NSLog
        case Print
        case Beaver
    }
    static let loggerType = LoggerType.Print
    
    static func different(_ message: String, prevMessage: String)
    {
        if message != prevMessage {
            printMessage("DIF> " + message)
        }
    }
    
    static func gui(_ message: String)
    {
        printMessage("GUI> " + message)
    }
    
    static func misc(_ message: String)
    {
        printMessage("MISC> " + message)
    }
    
    static func downloader(_ message: String)
    {
        printMessage("NET> " + message)
    }
        
    static func load(_ message: String)
    {
        printMessage("LOAD> " + message)
    }
    
    static func model(_ message: String)
    {
        printMessage("MOD> " + message)
    }
    
    static func engine(_ message: String)
    {
        printMessage("ENG> " + message)
    }

    static func iap(_ message: String)
    {
        printMessage("IAP> " + message)
    }
    
    static func gpx(_ message: String)
    {
        printMessage("GPX> " + message)
    }
    
    static func niy()
    {
        printMessage("Not implemented yet!")
    }
    
    static func warn(_ message: String)
    {
        printMessage("WARN **> " + message)
    }
    
    static func error(_ message: String)
    {
        printMessage("ERR ****> " + message)
    }
    
    static func printMessage(_ message: String)
    {
        switch loggerType {
        case .NSLog:
            NSLog(message)
            break
        case .Print:
            print(message)
            break
        case .Beaver:
            initialize()
            if message.starts(with: "ERR") {
                SwiftyBeaver.self.error(message)
            }
            else if message.starts(with: "WARN") {
                SwiftyBeaver.self.warning(message)
            }
            else {
                SwiftyBeaver.self.info(message)
            }
            break
        }
    }
    
    static var inited = false
    static fileprivate func initialize()
    {
        if !inited {
            inited = true
            
            let log = SwiftyBeaver.self
            let console = ConsoleDestination()  // log to Xcode Console
            let cloud = SBPlatformDestination(appID: "dGPZzv", appSecret: "tzkr04HzuPaz1hmbyyuqgdpzbkSxulpK", encryptionKey: "1vccjSktorx7mstfJcjubatb8Vvubgqg")
            console.format = "$DHH:mm:ss$d $L $M"
            log.addDestination(console)
            log.addDestination(cloud)
        }
    }
    
    // ------------------------------------------------------------------------------------------------------
    // MARK: - End
    // ------------------------------------------------------------------------------------------------------
}
