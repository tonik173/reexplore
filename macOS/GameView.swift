//
//  GameView.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 16.06.2020.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import MetalKit

class GameView: MTKView
{
    weak var inputController: InputController? {
        didSet {
            if let inputController = self.inputController {
                self.speed = Int(inputController.translationSpeed)
            }
        }
    }
    var trackingArea : NSTrackingArea?
    var useMouse = true { didSet { inputController?.useMouse = useMouse } }
    var geolocation: String?
    var speed: Int = 0
    
    @IBAction func copyGPX(_ sender: Any)
    {
        if let location = self.geolocation {
            let loc = location.replacingOccurrences(of: " ", with: "")
            Log.gui("coping GPX, invoke \(loc)")
            if let targetURL = NSURL(string: "maps://?ll=\(loc)&spn=0.005,0.005&t=h") {
                NSWorkspace.shared.open(targetURL as URL)
           }
        }
    }
    
    override func updateTrackingAreas()
    {
        guard let window = NSApplication.shared.mainWindow else { return }
        window.acceptsMouseMovedEvents = useMouse
        if useMouse {
            // CGDisplayHideCursor(CGMainDisplayID())
        }
        else {
            CGDisplayShowCursor(CGMainDisplayID())
        }
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        guard useMouse else { return }
        
        let options: NSTrackingArea.Options = [.activeAlways, .inVisibleRect,  .mouseMoved]
        trackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }

    override var acceptsFirstResponder: Bool { return true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { return true }
    
    override func keyDown(with event: NSEvent)
    {
        // Log.gui("key = \(event.keyCode)")
        guard let key = KeyboardControl(rawValue: event.keyCode) else {
            super.keyDown(with: event)
            return
        }
        
        let state: InputState = event.isARepeat ? .continued : .began
        inputController?.processEvent(key: key, state: state)
    }
    
    override func keyUp(with event: NSEvent)
    {
        guard let key = KeyboardControl(rawValue: event.keyCode) else {
            super.keyUp(with: event)
            return
        }
        
        if let inputController = inputController {
            inputController.processEvent(key: key, state: .ended)
            self.speed = Int(inputController.translationSpeed)
        }
    }
    
    override func mouseMoved(with event: NSEvent)
    {
        inputController?.processEvent(mouse: .mouseMoved, state: .began, event: event)
    }
    
    override func mouseDown(with event: NSEvent)
    {
        inputController?.processEvent(mouse: .leftDown, state: .began, event: event)
    }
    
    override func mouseUp(with event: NSEvent)
    {
        inputController?.processEvent(mouse: .leftUp, state: .ended, event: event)
    }
    
    override func mouseDragged(with event: NSEvent)
    {
        inputController?.processEvent(mouse: .leftDrag, state: .continued, event: event)
    }
    
    override func rightMouseDown(with event: NSEvent)
    {
        inputController?.processEvent(mouse: .rightDown, state: .began, event: event)
    }
    
    override func rightMouseDragged(with event: NSEvent)
    {
        inputController?.processEvent(mouse: .rightDrag, state: .continued, event: event)
    }
    
    override func rightMouseUp(with event: NSEvent)
    {
        inputController?.processEvent(mouse: .rightUp, state: .ended, event: event)
    }
    
    override func scrollWheel(with event: NSEvent)
    {
        inputController?.processEvent(mouse: .scroll, state: .continued, event: event)
    }
}

class MiniGameView: MiniGameViewBase
{
    override func viewDidEndLiveResize()
    {
        super.viewDidEndLiveResize()
        self.resizeElevation(frame: self.bounds)
    }
}
