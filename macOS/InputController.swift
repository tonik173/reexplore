//
//  InputController.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 16.06.2020.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import Cocoa

class InputController
{
    var keysDown: Set<KeyboardControl> = []
    var player: Node?
    var inputDeviceDelegate: InputDeviceDelegate?
    var useMouse = true
    
    var translationSpeed: Float = 3
    fileprivate let translateSpeedFactor: Float = 0.5
    fileprivate let rotationSpeed: Float = 1.0
    
    public func updatePlayer(deltaTime: Float) -> InputControlInfo
    {
        if let player = self.player {
            var direction: float3 = [0, 0, 0]
            var didTranslate = false
            var didRotate = false
            let translationSpeed = deltaTime * self.translationSpeed * 5
            let rotationSpeed = deltaTime * self.rotationSpeed
            for key in keysDown {
                switch key {
                case .up, .w:
                    direction.z += 1
                    didTranslate = true
                case .down, .s:
                    direction.z -= 1
                    didTranslate = true
                case .left, .a:
                    player.rotation.y -= rotationSpeed
                    didRotate = true
                case .right, .d:
                    player.rotation.y += rotationSpeed
                    didRotate = true
                case .n1, .k1:
                    self.translationSpeed = 1
                case .n2, .k2:
                    self.translationSpeed = 2
                case .n3, .k3:
                    self.translationSpeed = 3
                case .n4, .k4:
                    self.translationSpeed = 4
                case .n5, .k5:
                    self.translationSpeed = 5
                case .n6, .k6:
                    self.translationSpeed = 6
                case .n7, .k7:
                    self.translationSpeed = 7
                case .n8, .k8:
                    self.translationSpeed = 8
                case .n9, .k9:
                    self.translationSpeed = 9
                case .plus:
                    self.translationSpeed = min(self.translationSpeed + 1, 9)
                    self.keysDown.remove(.plus)
                case .minus:
                    self.translationSpeed = max(self.translationSpeed - 1, 1)
                    self.keysDown.remove(.minus)
                default:
                    break
                }
            }
            if didTranslate || didRotate {
                direction = length(direction) > 0 ? normalize(direction) : direction
                let directionChange = (direction.z * player.forwardVector + direction.x * player.rightVector) * translationSpeed * translateSpeedFactor
                player.position += directionChange
                
                return InputControlInfo(direction: float2(x: directionChange.x, y: directionChange.z), didTranslate: didTranslate, didRotate: didRotate, translationSpeed: self.translationSpeed/8)
            }
        }
        
        return InputControlInfo()
    }
    
    func processEvent(key inKey: KeyboardControl, state: InputState)
    {
        let key = inKey
        if state == .began {
            keysDown.insert(key)
        }
        if state == .ended {
            keysDown.remove(key)
        }
    }
    
    func processEvent(mouse: MouseControl, state: InputState, event: NSEvent)
    {
        let delta: float3 = [Float(event.deltaX), Float(event.deltaY), Float(event.deltaZ)]
        let locationInWindow: float2 = [Float(event.locationInWindow.x), Float(event.locationInWindow.y)]
        //Log.gui("mouse \(mouse) at location \(locationInWindow.x)/\(locationInWindow.y) with state \(state) and modifier \(event.type.rawValue), delta: \(delta.x)/\(delta.y)/\(delta.z)")
        inputDeviceDelegate?.moveEvent(delta: delta, location: locationInWindow)
    }
}

enum InputState {
    case began, moved, ended, cancelled, continued
}

enum KeyboardControl: UInt16 {
    case a =      0
    case d =      2
    case w =      13
    case s =      1
    case down =   125
    case up =     126
    case right =  124
    case left =   123
    case q =      12
    case e =      14
    case space =  49
    case c =      8
    case f =      3
    case k0 =     29
    case k1 =     18
    case k2 =     19
    case k3 =     20
    case k4 =     21
    case k5 =     23
    case k6 =     22
    case k7 =     26
    case k8 =     28
    case k9 =     25
    case n0 =     82
    case n1 =     83
    case n2 =     84
    case n3 =     85
    case n4 =     86
    case n5 =     87
    case n6 =     88
    case n7 =     89
    case n8 =     91
    case n9 =     92
    case plus =   69
    case minus =  78
}

enum MouseControl {
    case leftDown, leftUp, leftDrag, rightDown, rightUp, rightDrag, scroll, mouseMoved
}

