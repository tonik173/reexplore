//
//  Shadow.metal
//  Reexplore
//
//  Created by Toni Kaufmann on 07.02.21.
//  Copyright © 2021 n3xd software studios ag. All rights reserved.
//
#include <metal_stdlib>
using namespace metal;
#import "Common.h"

struct VertexIn {
    float4 position [[attribute(Position)]];
};

vertex float4 vertex_depth(const VertexIn vertexIn [[ stage_in ]],
                           constant Instances *instances [[buffer(BufferIndexInstances)]],
                           uint instanceID [[instance_id]],
                           constant Uniforms &uniforms [[buffer(BufferIndexUniforms)]])
{
    Instances instance = instances[instanceID];
    matrix_float4x4 mvp = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix * instance.modelMatrix;
    float4 position = mvp * vertexIn.position;
    return position;
}
