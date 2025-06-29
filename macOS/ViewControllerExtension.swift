//
//  ViewController.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 16.06.2020.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import Cocoa

extension ViewController
{
    func addGestureRecognizers(to view: NSView)
    {
        let pan = NSPanGestureRecognizer(target: self, action: #selector(handlePan(gesture:)))
        view.addGestureRecognizer(pan)
    }
    
    @objc func handlePan(gesture: NSPanGestureRecognizer)
    {
        let translation = gesture.translation(in: gesture.view)
        let delta = float2(Float(translation.x), Float(translation.y))
        
        if let camera = renderer?.scene?.camera(forType: self.gameConfig.cameraType) {
            camera.rotate(delta: delta)
        }
        gesture.setTranslation(.zero, in: gesture.view)
    }
    
    override func scrollWheel(with event: NSEvent)
    {
        if let camera = renderer?.scene?.camera(forType: self.gameConfig.cameraType) {
            camera.zoom(delta: Float(event.deltaY))
        }
    }
}
