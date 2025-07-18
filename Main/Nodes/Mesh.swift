//
//  Mesh.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 16.06.2020.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import MetalKit

struct Mesh
{
    let mtkMesh: MTKMesh
    let submeshes: [Submesh]
    let transform: TransformComponent?
    let skeleton: Skeleton?
    
    init(mdlMesh: MDLMesh, mtkMesh: MTKMesh, startTime: TimeInterval, endTime: TimeInterval, vertexFunctionName: String, fragmentFunctionName: String)
    {
        // load skeleton
        let skeleton =  Skeleton(animationBindComponent: (mdlMesh.componentConforming(to: MDLComponent.self) as? MDLAnimationBindComponent))
        self.skeleton = skeleton
        
        // load submeshes
        self.mtkMesh = mtkMesh
        submeshes = zip(mdlMesh.submeshes!, mtkMesh.submeshes).map { mesh in
            Submesh(mdlSubmesh: mesh.0 as! MDLSubmesh,
                    mtkSubmesh: mesh.1,
                    hasSkeleton: skeleton != nil,
                    vertexFunctionName: vertexFunctionName,
                    fragmentFunctionName: fragmentFunctionName)
        }
        
        if let mdlMeshTransform = mdlMesh.transform {
            transform = TransformComponent(transform: mdlMeshTransform, object: mdlMesh, startTime: startTime, endTime: endTime)
        }
        else {
            transform = nil
        }
    }
}
