//
//  Skybox.metal
//  Reexplore
//
//  Created by Toni Kaufmann on 16.06.2020.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
#include <metal_stdlib>
using namespace metal;
#include "Common.h"

struct VertexIn {
    float4 position [[attribute(0)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 textureCoordinates;
};

vertex VertexOut vertexSkybox(const VertexIn in [[stage_in]],
                              constant float4x4 &vp [[buffer(1)]])
{
    VertexOut out;
    out.position = (vp * in.position).xyww;
    out.textureCoordinates = in.position.xyz;
    return out;
}

fragment half4 fragmentSkybox(VertexOut in [[stage_in]],
                              texturecube<half> cubeTexture [[texture(BufferIndexSkybox)]])
{
    constexpr sampler default_sampler(filter::linear);
    half4 color = cubeTexture.sample(default_sampler, in.textureCoordinates);
    return color;
}

