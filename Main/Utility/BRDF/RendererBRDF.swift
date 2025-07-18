//
//  Renderer.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 16.06.2020.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import Metal

extension Renderer
{
    static func buildBRDF() -> MTLTexture?
    {
        let size = 256
        guard let brdfFunction = Renderer.makeFunction(name: "integrateBRDF"),
            let brdfPipelineState = try? Renderer.device.makeComputePipelineState(function: brdfFunction),
            let commandBuffer = Renderer.commandQueue.makeCommandBuffer(),
            let commandEncoder = commandBuffer.makeComputeCommandEncoder() else { return nil }
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rg16Float, width: size, height: size, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        let lut = Renderer.device.makeTexture(descriptor: descriptor)
        
        commandEncoder.setComputePipelineState(brdfPipelineState)
        commandEncoder.setTexture(lut, index: 0)
        let threadsPerThreadgroup = MTLSizeMake(16, 16, 1)
        let threadgroups = MTLSizeMake(size / threadsPerThreadgroup.width, size / threadsPerThreadgroup.height, 1)
        commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
        commandEncoder.endEncoding()
        commandBuffer.commit()
        return lut
    }
}
