//
//  Renderable.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 16.06.2020.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import MetalKit

protocol Renderable
{
    var name: String { get }
    func render(renderEncoder: MTLRenderCommandEncoder, uniforms: Uniforms, fragmentUniforms fragment: FragmentUniforms)
    func render(renderEncoder: MTLRenderCommandEncoder, uniforms: Uniforms)
}
