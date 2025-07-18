//
//  InputController.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 16.06.2020.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import MetalKit

class InputController
{
    var player: Node?
    var currentPitch: Float = 0
    var inputDeviceDelegate: InputDeviceDelegate?
        
    fileprivate var translationSpeed: Float = 0
    fileprivate var currentSpeed: Float = 0
    fileprivate var forward = false

    fileprivate var locStart: CGPoint = .zero
    
    func processEvent(touches: Set<UITouch>, state: InputState, event: UIEvent?, in view: UIView)
    {
        guard let firstTouch = touches.first else { return }
               
        switch state {
        case .began:
            forward = true
            locStart = firstTouch.location(in: view)
        case .moved:
            let location = firstTouch.location(in: view)
            self.translationSpeed = Float(locStart.y - location.y)*0.02
            self.currentPitch = Float(location.x - locStart.x)*0.01
            forward = true
        case .ended:
            forward = false
            currentPitch = 0
        default:
            break
        }
    }
    
    public func updatePlayer(deltaTime: Float) -> InputControlInfo
    {
        if let player = self.player {
            var direction: float3 = [0, 0, 0]
            var didTranslate = false
            var didRotate = false
            
            currentSpeed = forward ? deltaTime * self.translationSpeed : 0
            currentSpeed = min(0.5, max(-0.1, currentSpeed))
             
            let rotationSpeed: Float = 3.0
            player.rotation.y += currentPitch * deltaTime * rotationSpeed * sign(currentSpeed + 0.01)
            
            // Log.gui("currentSpeed: \(currentSpeed), translationSpeed: \(self.translationSpeed), player.rotation.y \(player.rotation.y), currentPitch: \(currentPitch)")
            if currentSpeed != 0 {
                direction.z = 1
                didTranslate = true
            }
            if (currentPitch != 0) {
                didRotate = true
            }
            
            if didTranslate || didRotate {
                direction = length(direction) > 0 ? normalize(direction) : direction
                let directionChange = (direction.z * player.forwardVector + direction.x * player.rightVector) * translationSpeed
                player.position += directionChange
                
                return InputControlInfo(direction: float2(x: directionChange.x, y: directionChange.z), didTranslate: didTranslate, didRotate: didRotate, translationSpeed: self.translationSpeed)
            }
        }
        return InputControlInfo()
    }
}

enum InputState {
    case began, moved, ended, cancelled, continued
}


