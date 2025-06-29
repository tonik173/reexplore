//
//  Platform.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 19.02.21.
//  Copyright © 2021 n3xd software studios ag. All rights reserved.
//
import Foundation

struct Platform
{
    static func compileVersionString(includeBundleNumber: Bool = false, withBuildDate useBuildDate: Bool = false) -> String
    {
        var build = "r"
        var simulator = ""
        #if DEBUG
            build = "d"
        #endif
        #if targetEnvironment(simulator)
            simulator = "-sim"
        #endif
        
        if let bundleShortVersion: AnyObject = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as AnyObject? {
            var version = bundleShortVersion.description!
            if includeBundleNumber {
                if let bundleVersion: AnyObject = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as AnyObject? {
                    version += build + bundleVersion.description + simulator
                }
            }
            if useBuildDate {
                let date = ObjCHelpers.compileDate() ?? "2019"
                let time = ObjCHelpers.compileTime() ?? "12:00"
                version += " \(date) \(time)"
            }
            
            return version
        }
        return "n/a"
    }
}
