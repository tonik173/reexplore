//
//  Submesh.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 16.06.2020.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import MetalKit

class Submesh
{
    var mtkSubmesh: MTKSubmesh
    
    struct Textures {
        let baseColor: MTLTexture?
        let normal: MTLTexture?
        let roughness: MTLTexture?
        let metallic: MTLTexture?
        let ao: MTLTexture?
    }
    
    let textures: Textures
    let material: Material
    var texturesBuffer: MTLBuffer!
    let fragmentFunction: MTLFunction
    let pipelineState: MTLRenderPipelineState
    
    init(mdlSubmesh: MDLSubmesh, mtkSubmesh: MTKSubmesh, hasSkeleton: Bool, vertexFunctionName: String, fragmentFunctionName: String)
    {
        self.mtkSubmesh = mtkSubmesh
        textures = Textures(material: mdlSubmesh.material)
        material = Material(material: mdlSubmesh.material)
        
        let constantValues = Submesh.makeVertexFunctionConstants(hasSkeleton: hasSkeleton)
        guard let vertexFunction = Renderer.makeFunction(name: vertexFunctionName, constantValues: constantValues)
        else { fatalError("make vertex function failed") }
        
        let functionConstants = Submesh.makeFunctionConstants(textures: textures)
        guard let fragmentFunction = Renderer.makeFunction(name: fragmentFunctionName, constantValues: functionConstants) else { fatalError("make fragment function failed") }
        self.fragmentFunction = fragmentFunction

        pipelineState = Submesh.makePipelineState(vertexFunction: vertexFunction, fragmentFunction: fragmentFunction)
    }
}

// Pipeline state
private extension Submesh
{
    static func makeFunctionConstants(textures: Textures) -> MTLFunctionConstantValues
    {
        let functionConstants = MTLFunctionConstantValues()
        var property = textures.baseColor != nil
        functionConstants.setConstantValue(&property, type: .bool, index: 0)
        property = textures.normal != nil
        functionConstants.setConstantValue(&property, type: .bool, index: 1)
        property = textures.roughness != nil
        functionConstants.setConstantValue(&property, type: .bool, index: 2)
        property = textures.metallic != nil
        functionConstants.setConstantValue(&property, type: .bool, index: 3)
        property = textures.ao != nil
        functionConstants.setConstantValue(&property, type: .bool, index: 4)
        return functionConstants
    }
    
    static func makeVertexFunctionConstants(hasSkeleton: Bool) -> MTLFunctionConstantValues
    {
        let functionConstants = MTLFunctionConstantValues()
        var addSkeleton = hasSkeleton
        functionConstants.setConstantValue(&addSkeleton, type: .bool, index: 5)
        return functionConstants
    }
    
    static func makePipelineState(vertexFunction: MTLFunction, fragmentFunction: MTLFunction) -> MTLRenderPipelineState
    {
        var pipelineState: MTLRenderPipelineState
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        
        let vertexDescriptor = Model.vertexDescriptor
        pipelineDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(vertexDescriptor)
        pipelineDescriptor.colorAttachments[0].pixelFormat = Renderer.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        do {
            pipelineState = try Renderer.device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch let error {
            fatalError(error.localizedDescription)
        }
        return pipelineState
    }
}


extension Submesh: Texturable {}

private extension Submesh.Textures
{
    init(material: MDLMaterial?)
    {
        func property(with semantic: MDLMaterialSemantic) -> MTLTexture?
        {
            guard let property = material?.property(with: semantic),
                property.type == .string,
                let filename = property.stringValue,
                let texture = try? Submesh.loadTexture(imageName: filename)
                else {
                    if let property = material?.property(with: semantic),
                        property.type == .texture,
                        let mdlTexture = property.textureSamplerValue?.texture {
                        return try? Submesh.loadTexture(texture: mdlTexture)
                    }
                    return nil
            }
            return texture
        }
        baseColor = property(with: MDLMaterialSemantic.baseColor)
        normal = property(with: .tangentSpaceNormal)
        roughness = property(with: .roughness)
        metallic = property(with: .metallic)
        ao = property(with: .ambientOcclusion)
    }
}

private extension Material
{
    init(material: MDLMaterial?)
    {
        self.init()
        if let baseColor = material?.property(with: .baseColor), baseColor.type == .float3 {
            self.baseColor = baseColor.float3Value
        }
        if let specular = material?.property(with: .specular), specular.type == .float3 {
            self.specularColor = specular.float3Value
        }
        if let shininess = material?.property(with: .specularExponent), shininess.type == .float {
            self.shininess = shininess.floatValue
        }
        if let roughness = material?.property(with: .roughness), roughness.type == .float3 {
            self.roughness = roughness.floatValue
        }
    }
}

