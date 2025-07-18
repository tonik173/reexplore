//
//  RenderPass.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 16.06.2020.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import MetalKit

class RenderPass
{
    var descriptor: MTLRenderPassDescriptor
    var texture: MTLTexture
    var depthTexture: MTLTexture
    let name: String
    
    init(name: String, size: CGSize)
    {
        self.name = name
        texture = RenderPass.buildTexture(size: size, label: name, pixelFormat: .bgra8Unorm, usage: [.renderTarget, .shaderRead])
        depthTexture = RenderPass.buildTexture(size: size, label: name, pixelFormat: .depth32Float, usage: [.renderTarget, .shaderRead])
        descriptor = RenderPass.setupRenderPassDescriptor(texture: texture, depthTexture: depthTexture)
    }
    
    func updateTextures(size: CGSize)
    {
        texture = RenderPass.buildTexture(size: size, label: name, pixelFormat: .bgra8Unorm, usage: [.renderTarget, .shaderRead])
        depthTexture = RenderPass.buildTexture(size: size, label: name, pixelFormat: .depth32Float, usage: [.renderTarget, .shaderRead])
        descriptor = RenderPass.setupRenderPassDescriptor(texture: texture, depthTexture: depthTexture)
    }
    
    static func setupRenderPassDescriptor(texture: MTLTexture, depthTexture: MTLTexture) -> MTLRenderPassDescriptor
    {
        let descriptor = MTLRenderPassDescriptor()
        descriptor.setUpColorAttachment(position: 0, texture: texture)
        descriptor.setUpDepthAttachment(texture: depthTexture)
        return descriptor
    }
}

extension RenderPass: Texturable {}

private extension MTLRenderPassDescriptor
{
    func setUpDepthAttachment(texture: MTLTexture)
    {
        depthAttachment.texture = texture
        depthAttachment.loadAction = .clear
        depthAttachment.storeAction = .dontCare
        depthAttachment.clearDepth = 1
    }
    
    func setUpColorAttachment(position: Int, texture: MTLTexture)
    {
        let attachment: MTLRenderPassColorAttachmentDescriptor = colorAttachments[position]
        attachment.texture = texture
        attachment.loadAction = .clear
        attachment.storeAction = .store
        attachment.clearColor = MTLClearColorMake(0, 0, 0, 0)
    }
}
