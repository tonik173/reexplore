//
//  Node.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 16.06.2020.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import MetalKit

class Node: CustomStringConvertible
{
    var description: String { String(describing: self.name) }
    
    var name: String = "untitled"
    var position: float3 = [0, 0, 0]
    var rotation: float3 = [0, 0, 0] {
        didSet {
            let rotationMatrix = float4x4(rotation: rotation)
            quaternion = simd_quatf(rotationMatrix)
        }
    }
    var quaternion = simd_quatf()
    var scale:float3 = [1, 1, 1]
    
    var modelMatrix: float4x4 {
        let translateMatrix = float4x4(translation: position)
        let rotateMatrix = float4x4(quaternion)
        let scaleMatrix = float4x4(scaling: scale)
        return translateMatrix * rotateMatrix * scaleMatrix
    }
    
    var boundingBox = MDLAxisAlignedBoundingBox()
    var size: float3 {
        return boundingBox.maxBounds - boundingBox.minBounds
    }
    
    var parent: Node?
    var children: [Node] = []
    
    var fillMode: MTLTriangleFillMode = .fill
    
    func updateGameConfig(_ gameConfig: GameConfig, changed: GameConfig.ChangedProperty)
    {
        if changed == .debugWirefame {
            self.fillMode = gameConfig.showWireframe ? .lines : .fill
        }
    }
    
    func update(deltaTime: Float)
    {
        // override this
    }
    
    final func add(childNode: Node)
    {
        children.append(childNode)
        childNode.parent = self
    }
    
    final func add(childNodes: [Node])
    {
        for index in childNodes.indices {
            childNodes[index].parent = self
        }
        children.append(contentsOf: childNodes)
    }
    
    final func remove(childNode: Node)
    {
        for child in childNode.children {
            child.parent = self
            children.append(child)
        }
        childNode.children = []
        guard let index = (children.firstIndex {
            $0 === childNode
        }) else { return }
        children.remove(at: index)
        childNode.parent = nil
    }
    
    var worldTransform: float4x4 {
        if let parent = parent {
            return parent.worldTransform * self.modelMatrix
        }
        return modelMatrix
    }
    
    var forwardVector: float3 {
        return normalize([sin(rotation.y), 0, cos(rotation.y)])
    }
    
    var rightVector: float3 {
        return [forwardVector.z, forwardVector.y, -forwardVector.x]
    }
}

