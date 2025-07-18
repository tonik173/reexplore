//
//  Skybox.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 16.06.2020.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import MetalKit

class Skybox
{
    let mesh: MTKMesh
    var texture: MTLTexture?
    let pipelineState: MTLRenderPipelineState
    let depthStencilState: MTLDepthStencilState?
    
    struct SkySettings {
        var turbidity: Float = 1.0
        var sunElevation: Float = 0.77
        var upperAtmosphereScattering: Float = 0.93
        var groundAlbedo: Float = 0.1
    }
    
    var skySettings = SkySettings()
    var diffuseTexture: MTLTexture?
    var brdfLut: MTLTexture?
    
    init(textureName: String?)
    {
        let allocator = MTKMeshBufferAllocator(device: Renderer.device)
        let cube = MDLMesh(boxWithExtent: [1,1,1], segments: [1, 1, 1], inwardNormals: true, geometryType: .triangles, allocator: allocator)
        do {
            mesh = try MTKMesh(mesh: cube, device: Renderer.device)
        } catch {
            fatalError("failed to create skybox mesh")
        }
        pipelineState = Skybox.buildPipelineState(vertexDescriptor: cube.vertexDescriptor)
        depthStencilState = Skybox.buildDepthStencilState()
        if textureName == nil {
            texture = loadGeneratedSkyboxTexture(dimensions: [256, 256])
            diffuseTexture = texture
        }
        else {
            do {
                texture = try Skybox.loadCubeTexture(imageName: textureName!)
                let irradiance = "irradiance-" + textureName! + ".png"
                diffuseTexture = try Skybox.loadCubeTexture(imageName: irradiance)
            } catch {
                fatalError(error.localizedDescription)
            }
        }
        brdfLut = Renderer.buildBRDF()
    }
    
    func loadGeneratedSkyboxTexture(dimensions: int2) -> MTLTexture?
    {
        var texture: MTLTexture?
        let skyTexture = MDLSkyCubeTexture(name: "sky",
                                           channelEncoding: .uInt8,
                                           textureDimensions: dimensions,
                                           turbidity: skySettings.turbidity,
                                           sunElevation: skySettings.sunElevation,
                                           upperAtmosphereScattering: skySettings.upperAtmosphereScattering,
                                           groundAlbedo: skySettings.groundAlbedo)
        do {
            let textureLoader = MTKTextureLoader(device: Renderer.device)
            texture = try textureLoader.newTexture(texture: skyTexture, options: nil)
        } catch {
            print(error.localizedDescription)
        }
        return texture
    }
    
    private static func buildPipelineState(vertexDescriptor: MDLVertexDescriptor) -> MTLRenderPipelineState
    {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.colorAttachments[0].pixelFormat = Renderer.colorPixelFormat
            descriptor.depthAttachmentPixelFormat = .depth32Float
            descriptor.vertexFunction = Renderer.makeFunction(name: "vertexSkybox")
            descriptor.fragmentFunction = Renderer.makeFunction(name: "fragmentSkybox")
            descriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(vertexDescriptor)
            do {
                return try Renderer.device.makeRenderPipelineState(descriptor: descriptor)
            } catch {
                fatalError(error.localizedDescription)
            }
    }
    
    private static func buildDepthStencilState() -> MTLDepthStencilState?
    {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .lessEqual
        descriptor.isDepthWriteEnabled = true
        return Renderer.device.makeDepthStencilState(descriptor: descriptor)
    }
    
    func update(renderEncoder: MTLRenderCommandEncoder)
    {
        renderEncoder.setFragmentTexture(texture, index: Int(BufferIndexSkybox.rawValue))
        renderEncoder.setFragmentTexture(diffuseTexture, index: Int(BufferIndexSkyboxDiffuse.rawValue))
        renderEncoder.setFragmentTexture(brdfLut, index: Int(BufferIndexBRDFLut.rawValue))
    }
    
    func render(renderEncoder: MTLRenderCommandEncoder, uniforms: Uniforms)
    {
        renderEncoder.pushDebugGroup("Skybox")
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthStencilState)
        renderEncoder.setVertexBuffer(mesh.vertexBuffers[0].buffer, offset: 0, index: 0)
        var viewMatrix = uniforms.viewMatrix
        viewMatrix.columns.3 = [0, 0, 0, 1]
        var viewProjectionMatrix = uniforms.projectionMatrix * viewMatrix
        renderEncoder.setVertexBytes(&viewProjectionMatrix, length: MemoryLayout<float4x4>.stride, index: 1)
        let submesh = mesh.submeshes[0]
        renderEncoder.setFragmentTexture(texture, index: Int(BufferIndexSkybox.rawValue))
        renderEncoder.drawIndexedPrimitives(type: .triangle,
                                            indexCount: submesh.indexCount,
                                            indexType: submesh.indexType,
                                            indexBuffer: submesh.indexBuffer.buffer,
                                            indexBufferOffset: 0)
    }
}

extension Skybox: Texturable {}

