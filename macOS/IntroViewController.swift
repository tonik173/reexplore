//
//  IntroViewController.swift
//  Reexplore-macOS
//
//  Created by Toni Kaufmann on 08.01.21.
//  Copyright © 2021 n3xd software studios ag. All rights reserved.
//
import Cocoa
import AVKit

class IntroViewController: NSViewController
{
    @IBOutlet var playerView: AVPlayerView!
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        guard let path = Bundle.main.path(forResource: "help-macos", ofType: "mp4") else { return }
        let player = AVPlayer(url: URL(fileURLWithPath: path))
        
        playerView.player = player;
        player.play()
    }
}
