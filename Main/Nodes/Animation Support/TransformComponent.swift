//
//  TransformComponent.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 16.06.2020.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import ModelIO

class TransformComponent
{
    let keyTransforms: [float4x4]
    let duration: Float
    var currentTransform: float4x4 = .identity()
    
    init(transform: MDLTransformComponent, object: MDLObject, startTime: TimeInterval, endTime: TimeInterval)
    {
        duration = Float(endTime - startTime)
        let timeStride = stride(from: startTime, to: endTime, by: 1 / TimeInterval(Renderer.fps))
        keyTransforms = Array(timeStride).map { time in
            return MDLTransform.globalTransform(with: object, atTime: time)
        }
    }
    
    func setCurrentTransform(at time: Float)
    {
        guard duration > 0 else {
            currentTransform = .identity()
            return
        }
        let frame = Int(fmod(time, duration) * Float(Renderer.fps))
        if frame < keyTransforms.count {
            currentTransform = keyTransforms[frame]
        } else {
            currentTransform = keyTransforms.last ?? .identity()
        }
    }
}


