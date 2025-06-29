//
//  GameScene.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 16.06.2020.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import Foundation
import CoreGraphics

class GameScene: Scene
{
    static let firstPersonCameraInitialGearDistance = float3(0, 3, -5)
    static let firstPersonCameraInitialPosition = float3(0, 200.0, 0)

    static let orthoCameraInitialPosition = float3(0.0, 100.0, 0.0)
    static let orthoCameraInitialRotation = float3(.pi / 2.0, 0.0, 0.0)
    static let orthoCameraSize: Float = 75
    
    // matthew v0
    fileprivate static let modelName = "matthew.usdz"
    fileprivate static let idleAnimation = "Stand"
    fileprivate static let walkAnimation = "Walk"
    fileprivate static let runAnimation = "Run"
    fileprivate let gear = GearModel(name: modelName)
    static let gearInitialPosition = float3(repeating: 0.0)
    static let gearInitialScale = float3(repeating: 1)
    static let gearInitialRotation = float3(x: 0, y: 0, z: 0)
    fileprivate let gearBig = BigGearModel(name: modelName)
    static let bigGearInitialPosition = float3(0.0, 0.0, 0.0)
    static let bigGearInitialScale = float3(repeating: 20)
    
    fileprivate var totalDelta: Float = 0

    init(withSceneSize sceneSize: CGSize, gameConfig: GameConfig)
    {
        super.init(sceneSize: sceneSize, gameConfig: gameConfig)
    }
    
    override func setupScene()
    {
        // loads environment
        self.skybox = Skybox(textureName: "sky")
        
        // gear
        self.gear.position = GameScene.gearInitialPosition
        self.gear.scale = GameScene.gearInitialScale
        self.gear.rotation = GameScene.gearInitialRotation
        self.add(node: self.gear)
        self.gear.runAnimation(name: Self.walkAnimation)
        if let animation = self.gear.currentAnimation {
            animation.speed = 0
        }
        
        // gear big
        self.gearBig.position = GameScene.bigGearInitialPosition
        self.gearBig.scale = GameScene.bigGearInitialScale
        self.gearBig.rotation = GameScene.gearInitialRotation
        self.add(node: self.gearBig)
        self.gearBig.runAnimation(name: Self.idleAnimation)
        if let animation = self.gearBig.currentAnimation {
            animation.speed = 0
        }

        // first person camera
        self.add(node: self.firstPersonCamera, render: false)
        self.firstPersonCamera.position =  GameScene.firstPersonCameraInitialPosition
        self.firstPersonCamera.gearDistance = GameScene.firstPersonCameraInitialGearDistance

        // ortho camera
        self.orthoCamera.position = GameScene.orthoCameraInitialPosition
        self.orthoCamera.rotation = GameScene.orthoCameraInitialRotation
        self.add(node: self.orthoCamera, render: false)
        
        // input controller
        let player = Node()
        player.name = "player"
        self.inputController.player = player
        self.resetScene()
    }
    
    fileprivate func smoothValue(withNewValue value: Float, values: inout [Float], depth: Int) -> Float
    {
        if values.count > depth {
            values.remove(at: 0)
        }
        values.append(value)
        
        var avgValue: Float = 0
        for v in values {
            avgValue += v
        }
        
        avgValue /= Float(values.count)
        return avgValue
    }
    
    fileprivate var avgCameraYs = [Float]()
    fileprivate var avgPlayerYs = [Float]()
    fileprivate var avgAscend = [Float]()

    override func playerUpdated(player: Node)
    {
        super.playerUpdated(player: player)
        
        // pre-calculations
        let siny = sin(player.rotation.y)
        let cosy = cos(player.rotation.y)
        
        // first person camera
        let dx = siny * self.firstPersonCamera.gearDistance.z
        let dz = cosy * self.firstPersonCamera.gearDistance.z
        let cameraPosition = float3(x: player.position.x + dx, y: 0, z: player.position.z + dz)
        if let cameraY = self.height(forPosition: float2(x: cameraPosition.x, y: cameraPosition.z)) {
            let avgCameraY = self.smoothValue(withNewValue: cameraY, values: &avgCameraYs, depth: 5)
            let avgPlayerY = self.smoothValue(withNewValue: player.position.y, values: &avgPlayerYs, depth: 5)
           
            // camera ppsition
            let newCameraY = avgCameraY + self.firstPersonCamera.gearDistance.y
            let newCameraPosition = float3(x: cameraPosition.x, y: newCameraY, z: cameraPosition.z)
            self.firstPersonCamera.position = newCameraPosition
                     
            // camera look at
            let diff = player.position.y - cameraY
            let ascending =  self.smoothValue(withNewValue: diff, values: &avgAscend, depth: 5)
            let centerY = avgPlayerY + self.firstPersonCamera.gearDistance.y + ascending
            self.firstPersonCamera.center = float3(x: player.position.x, y: centerY, z: player.position.z)
            
            // Log.gui("ascending: \(ascending), cameraYoffset: \(newCameraY), avgCameraY: \(avgCameraY), avgPlayerY: \(avgPlayerY)")
        }
        
        // gear
        self.gear.position = player.position + GameScene.gearInitialPosition
        self.gear.rotation = float3(x: GameScene.gearInitialRotation.x, y: player.rotation.y, z: player.rotation.z)

        // big gear
        self.gearBig.position = float3(x: player.position.x, y: GameScene.bigGearInitialPosition.y, z: player.position.z)
        self.gearBig.rotation = self.gear.rotation

        //Log.engine("y:\(player.rotation.y) -> cos(y):\(cos(player.rotation.y)), sin(y):\(sin(player.rotation.y))")
    }
    
    override func updateAnimation(speed: Float)
    {
        let absoluteSpeed = abs(speed)
        if absoluteSpeed < 0.01 {
            self.gear.runAnimation(name: Self.idleAnimation)
        }
        else if absoluteSpeed < 0.5 {
            self.gear.runAnimation(name: Self.walkAnimation)
        }
        else {
            self.gear.runAnimation(name: Self.runAnimation)
        }
        
        let animationSpeed = absoluteSpeed > 0.01 ? absoluteSpeed*10 : 0
        if let animation = self.gear.currentAnimation {
            animation.speed = animationSpeed
            // Log.gui("animation \(animation.name) with speed: \(animation.speed), absoluteSpeed: \(absoluteSpeed)")
        }
        
        if let animation = self.gearBig.currentAnimation {
            animation.speed = animationSpeed
        }
    }
    
    override func resetScene()
    {
        super.resetScene()
        
        self.loadTerrainTiles()
        self.loadUploadTrack()
        
        if let offset = self.calculateExactPlayerOffset() {
            self.inputController.player?.position = float3(x: offset.x, y: 0, z: offset.y)
    
            // first person camera
            self.firstPersonCamera.position = float3(repeating: 0)
            self.firstPersonCamera.gearDistance = GameScene.firstPersonCameraInitialGearDistance

            // ortho camera
            orthoCamera.position = GameScene.orthoCameraInitialPosition
            self.sceneSizeWillChange(to: self.sceneSize) // resets the ortho camera to its start position
            self.relocateOrthoCameraView(by: offset)
            self.centerOrthoCameraView(toPosition: offset)
            
            // set camera height to current settings
            let delta = self.totalDelta
            self.totalDelta = 0
            self.updateCameraHeight(delta: delta)
        }
    }
    
    // the player is being relocated to the exact GPS coords (which are usually not in the middle of the tile)
    fileprivate func calculateExactPlayerOffset() -> float2?
    {
        if let initialTile = self.initialTile {
             let xOffset = (Float(initialTile.xf.truncatingRemainder(dividingBy: 1)) * TerrainTile.sideLen - TerrainTile.halfSideLen) * TerrainTile.scale
            let yOffset = (Float(1 - initialTile.yf.truncatingRemainder(dividingBy: 1)) * TerrainTile.sideLen - TerrainTile.halfSideLen) * TerrainTile.scale
            let offset = float2(x: xOffset, y: yOffset)
            return offset
        }
        return .none
    }
    
    override func updateCameraHeight(delta: Float)
    {
        // reset height smoothing buffer
        self.avgCameraYs = [Float]()
        self.avgPlayerYs = [Float]()
        
        self.totalDelta += delta
        self.firstPersonCamera.gearDistance += float3(x: 0, y: delta, z: -delta * 1.5)
        self.orthoCamera.scale += float3(repeating: delta/30)
        self.gearBig.scale += float3(repeating: delta)/3
    }
    
    override func sceneSizeWillChange(to size: CGSize)
    {
        super.sceneSizeWillChange(to: size)

        let ratio = Float(sceneSize.width / sceneSize.height)
        let rect = Rectangle(left: -GameScene.orthoCameraSize * ratio, right: GameScene.orthoCameraSize * ratio,
                             top: GameScene.orthoCameraSize, bottom: -GameScene.orthoCameraSize)
        self.orthoCamera.rect = rect
    }
    
    override func relocateOrthoCameraView(by distance: float2)
    {
        super.relocateOrthoCameraView(by: distance)
        let rect = self.orthoCamera.rect
        let x = distance.x / self.orthoCamera.scale.x
        let y = distance.y / self.orthoCamera.scale.z
        self.orthoCamera.rect = rect.move(x: x, y: y)
        Log.engine("Relocate ortho lt:\(rect.left)/\(rect.top), wh:lt:\(rect.left-rect.right)/\(rect.top-rect.bottom) move by xy:\(x)/\(y)")
    }
    
    override func centerOrthoCameraView(toPosition center: float2)
    {
        super.centerOrthoCameraView(toPosition: center)
        let rect = self.orthoCamera.rect
        let rectCenter = rect.center
        let x = rectCenter.x - center.x/self.orthoCamera.scale.x
        let y = rectCenter.y - center.y/self.orthoCamera.scale.y
        self.orthoCamera.rect = rect.move(x: -x, y: -y)
    }
    
    override func updateCollidedPlayer() -> Bool
    {
      /*  for body in physicsController.collidedBodies {
            if body.name == "oilcan.obj" {
                remove(node: body)
                physicsController.removeBody(node: body)
                oilcanCount -= 1
                if oilcanCount <= 0 {
                    print("ALL OILCANS FOUND!")
                } else {
                    print("Oilcans remaining: ", oilcanCount)
                }
                return true
            }
        }*/
        return false
    }
}
