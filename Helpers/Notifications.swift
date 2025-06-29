//
//  Notifications.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 19.03.21.
//  Copyright © 2021 n3xd software studios ag. All rights reserved.
//
import Foundation

struct Notifications
{
    static let updateSegment = NSNotification.Name(rawValue: "updateSegment")
    static let segmentPayload = "segmentPayload"
    static let segmentIndex = "segmentIndex"
    
    static func payload(forSegmentIndex index: String) -> [AnyHashable : Any]
    {
        let payload: [String : Any] = [Notifications.segmentIndex: index]
        return payload
    }
    
    static func payload(forUpdateSegmentNotification notification: Notification) -> String?
    {
        if let userinfo = notification.userInfo {
            return userinfo[Notifications.segmentIndex] as? String
        }
        return .none
    }
}
