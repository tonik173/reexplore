//
//  VertexDescriptor.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 16.06.2020.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import ModelIO

extension MDLVertexDescriptor
{
    static var defaultVertexDescriptor: MDLVertexDescriptor = {
        let vertexDescriptor = MDLVertexDescriptor()
        
        var offset = 0
        // position attribute
        vertexDescriptor.attributes[Int(Position.rawValue)]
            = MDLVertexAttribute(name: MDLVertexAttributePosition, format: .float3, offset: 0, bufferIndex: Int(BufferIndexVertices.rawValue))
        offset += MemoryLayout<float3>.stride
        
        // normal attribute
        vertexDescriptor.attributes[Int(Normal.rawValue)] =
            MDLVertexAttribute(name: MDLVertexAttributeNormal, format: .float3, offset: offset, bufferIndex: Int(BufferIndexVertices.rawValue))
        offset += MemoryLayout<float3>.stride
        
        // add the uv attribute here
        vertexDescriptor.attributes[Int(UV.rawValue)] =
            MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate, format: .float2, offset: offset, bufferIndex: Int(BufferIndexVertices.rawValue))
        offset += MemoryLayout<float2>.stride
        
        vertexDescriptor.attributes[Int(Tangent.rawValue)] =
            MDLVertexAttribute(name: MDLVertexAttributeTangent, format: .float3, offset: 0, bufferIndex: 1)
        
        vertexDescriptor.attributes[Int(Bitangent.rawValue)] =
            MDLVertexAttribute(name: MDLVertexAttributeBitangent, format: .float3, offset: 0, bufferIndex: 2)
        
        // color attribute
        vertexDescriptor.attributes[Int(Color.rawValue)] =
            MDLVertexAttribute(name: MDLVertexAttributeColor, format: .float3, offset: offset, bufferIndex: Int(BufferIndexVertices.rawValue))
        
        offset += MemoryLayout<float3>.stride
        
        // joints attribute
        vertexDescriptor.attributes[Int(Joints.rawValue)] =
            MDLVertexAttribute(name: MDLVertexAttributeJointIndices, format: .uShort4, offset: offset, bufferIndex: Int(BufferIndexVertices.rawValue))
        offset += MemoryLayout<ushort>.stride * 4
        
        vertexDescriptor.attributes[Int(Weights.rawValue)] =
            MDLVertexAttribute(name: MDLVertexAttributeJointWeights, format: .float4, offset: offset, bufferIndex: Int(BufferIndexVertices.rawValue))
        offset += MemoryLayout<float4>.stride
        
        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: offset)
        vertexDescriptor.layouts[1] = MDLVertexBufferLayout(stride: MemoryLayout<float3>.stride)
        vertexDescriptor.layouts[2] = MDLVertexBufferLayout(stride: MemoryLayout<float3>.stride)
        return vertexDescriptor
    }()
}
