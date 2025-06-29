//
//  AboutViewController.swift
//  Reexplore-macOS
//
//  Created by Toni Kaufmann on 28.12.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import Cocoa

class AboutViewController: NSViewController
{
    @IBAction func goToN3xd(_ sender: Any)
    {
        let url = URL(string: "https://www.n3xd.com")!
        if NSWorkspace.shared.open(url) {
            Log.gui("\(url) opened")
        }
    }
}
