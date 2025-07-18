//
//  SimpleModel.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 31.12.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import MetalKit

class SimpleModel: Node
{
    let meshes: [SimpleMesh]
    var vertexCount: Int = 0
    var tiling: UInt32 = 1
    let samplerState: MTLSamplerState?
    static var vertexDescriptor: MDLVertexDescriptor = MDLVertexDescriptor.defaultVertexDescriptor
    var complexity: ModelComplexityType
    
    var instanceCount: Int
    var instanceBuffer: MTLBuffer?
    
    init(name: String, vertexFunctionName: String = "vertex_simple", fragmentFunctionName: String = "fragment_simple", complexity: ModelComplexityType)
    {
        let ext = (name as NSString).pathExtension
        let fname = (name as NSString).deletingPathExtension
        guard let assetUrl = Bundle.main.url(forResource: fname, withExtension: ext) else { fatalError("Model: \(name) not found")  }
        let allocator = MTKMeshBufferAllocator(device: Renderer.device)
        let asset = MDLAsset(url: assetUrl, vertexDescriptor: MDLVertexDescriptor.defaultVertexDescriptor, bufferAllocator: allocator)
        
        // load meshes
        var mtkMeshes: [MTKMesh] = []
        let mdlMeshes = asset.childObjects(of: MDLMesh.self) as! [MDLMesh]
        _ = mdlMeshes.map { mdlMesh in
            Model.vertexDescriptor = mdlMesh.vertexDescriptor
            mtkMeshes.append(try! MTKMesh(mesh: mdlMesh, device: Renderer.device))
        }
        
        meshes = zip(mdlMeshes, mtkMeshes).map {
            SimpleMesh(mdlMesh: $0.0, mtkMesh: $0.1,
                       startTime: asset.startTime,
                       endTime: asset.endTime,
                       vertexFunctionName: vertexFunctionName,
                       fragmentFunctionName: fragmentFunctionName)
        }
        samplerState = SimpleModel.buildSamplerState()
        
        self.instanceCount = 0
        
        self.complexity = complexity
        super.init()
        
        self.name = name
        
        self.meshes.forEach { (mesh) in
            vertexCount += mesh.mtkMesh.vertexCount
        }
        
        Log.model("SimpleModel \(self.name) with \(vertexCount) vertices loaded.")
    }
    
    private static func buildSamplerState() -> MTLSamplerState?
    {
        let descriptor = MTLSamplerDescriptor()
        descriptor.sAddressMode = .repeat
        descriptor.tAddressMode = .repeat
        descriptor.mipFilter = .linear
        descriptor.maxAnisotropy = 8
        let samplerState = Renderer.device.makeSamplerState(descriptor: descriptor)
        return samplerState
    }
    
    func updateBuffer(transforms: [Instances])
    {
        if transforms.count == 0 {
            // clears the buffer
            self.instanceBuffer = .none
            self.instanceCount = 0
        }
        else {
            let length = MemoryLayout<Instances>.stride * transforms.count
            if let instanceBuffer = Renderer.device.makeBuffer(bytes: transforms, length: length, options: []) {
                self.instanceBuffer = instanceBuffer
                self.instanceCount = transforms.count
            }
        }
    }
}

extension SimpleModel: Renderable
{
    func render(renderEncoder: MTLRenderCommandEncoder, submesh: SimpleSubmesh)
    {
        let mtkSubmesh = submesh.mtkSubmesh
        renderEncoder.drawIndexedPrimitives(type: .triangle,
                                            indexCount: mtkSubmesh.indexCount,
                                            indexType: mtkSubmesh.indexType,
                                            indexBuffer: mtkSubmesh.indexBuffer.buffer,
                                            indexBufferOffset: mtkSubmesh.indexBuffer.offset,
                                            instanceCount: instanceCount)
    }
    
    func render(renderEncoder: MTLRenderCommandEncoder, uniforms vertex: Uniforms, fragmentUniforms fragment: FragmentUniforms)
    {
        guard let instanceBuffer = self.instanceBuffer else { return }
        
        var uniforms = vertex
        renderEncoder.setVertexBuffer(instanceBuffer, offset: 0, index: Int(BufferIndexInstances.rawValue))
        
        var fragmentUniforms = fragment
        fragmentUniforms.tiling = tiling
        renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<FragmentUniforms>.stride, index: Int(BufferIndexFragmentUniforms.rawValue))
        renderEncoder.setFragmentSamplerState(samplerState, index: 0)
        
        for mesh in meshes {
            uniforms.modelMatrix = worldTransform
            uniforms.normalMatrix = uniforms.modelMatrix.upperLeft
            renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: Int(BufferIndexUniforms.rawValue))
            
            for (index, vertexBuffer) in mesh.mtkMesh.vertexBuffers.enumerated() {
                renderEncoder.setVertexBuffer(vertexBuffer.buffer, offset: 0, index: index)
            }
            
            for submesh in mesh.submeshes {
                renderEncoder.setRenderPipelineState(submesh.pipelineState)
                var material = submesh.material
                renderEncoder.setFragmentBytes(&material, length: MemoryLayout<Material>.stride, index: Int(BufferIndexMaterials.rawValue))
                
                // perform draw call
                renderEncoder.pushDebugGroup(self.name)
                render(renderEncoder: renderEncoder, submesh: submesh)
                renderEncoder.popDebugGroup()
            }
        }
    }
    
    func render(renderEncoder: MTLRenderCommandEncoder, uniforms vertex: Uniforms)
    {
        guard let instanceBuffer = self.instanceBuffer else { return }
        
        var uniforms = vertex
        renderEncoder.setVertexBuffer(instanceBuffer, offset: 0, index: Int(BufferIndexInstances.rawValue))
        
        for mesh in meshes {
            uniforms.modelMatrix = worldTransform
            uniforms.normalMatrix = uniforms.modelMatrix.upperLeft
            renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: Int(BufferIndexUniforms.rawValue))
            
            for (index, vertexBuffer) in mesh.mtkMesh.vertexBuffers.enumerated() {
                renderEncoder.setVertexBuffer(vertexBuffer.buffer, offset: 0, index: index)
            }
            
            for submesh in mesh.submeshes {
                render(renderEncoder: renderEncoder, submesh: submesh)
            }
        }
    }
}

struct SimpleMesh
{
    let mtkMesh: MTKMesh
    let submeshes: [SimpleSubmesh]
    
    init(mdlMesh: MDLMesh, mtkMesh: MTKMesh, startTime: TimeInterval, endTime: TimeInterval, vertexFunctionName: String, fragmentFunctionName: String)
    {
        self.mtkMesh = mtkMesh
        submeshes = zip(mdlMesh.submeshes!, mtkMesh.submeshes).map { mesh in
            SimpleSubmesh(mdlSubmesh: mesh.0 as! MDLSubmesh,
                          mtkSubmesh: mesh.1,
                          vertexFunctionName: vertexFunctionName,
                          fragmentFunctionName: fragmentFunctionName)
        }
    }
}

class SimpleSubmesh
{
    var mtkSubmesh: MTKSubmesh
    
    let material: Material
    let pipelineState: MTLRenderPipelineState
    var texturesBuffer: MTLBuffer!
    let fragmentFunction: MTLFunction
    
    init(mdlSubmesh: MDLSubmesh, mtkSubmesh: MTKSubmesh, vertexFunctionName: String, fragmentFunctionName: String)
    {
        self.mtkSubmesh = mtkSubmesh
        material = Material(material: mdlSubmesh.material)
        let vertexFunction = Renderer.makeFunction(name: vertexFunctionName)!
        fragmentFunction = Renderer.makeFunction(name: fragmentFunctionName)!
        pipelineState = SimpleSubmesh.makePipelineState(vertexFunction: vertexFunction, fragmentFunction: fragmentFunction)
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
        }
        catch let error {
            fatalError(error.localizedDescription)
        }
        return pipelineState
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



