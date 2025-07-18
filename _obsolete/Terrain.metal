//
//  Terrain.metal
//  Reexplore
//
//  Created by Toni Kaufmann on 18.06.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
#include <metal_stdlib>
using namespace metal;
#include "Common.h"

struct ControlPoint {
    float4 position [[attribute(0)]];
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
    float height;
    float2 uv;
    int textureIndex;
    bool isEdge;
};

struct VertexIn {
    float4 position [[attribute(0)]];
};

float calc_distance(float3 pointA, float3 pointB, float3 camera_position, float4x4 modelMatrix)
{
    float3 positionA = (modelMatrix * float4(pointA, 1)).xyz;
    float3 positionB = (modelMatrix * float4(pointB, 1)).xyz;
    float3 midpoint = (positionA + positionB) * 0.5;
    float camera_distance = distance(camera_position, midpoint);
    return camera_distance;
}

kernel void tessellation_terrain(device MTLQuadTessellationFactorsHalf* factors [[buffer(0)]],
                                 constant float4 &camera_position [[buffer(1)]],
                                 constant float4x4 &modelMatrix [[buffer(2)]],
                                 constant float3* control_points [[buffer(3)]],
                                 constant TerrainInfo &terrainInfo [[buffer(4)]],
                                 device float* y [[buffer(5)]],
                                 uint pid [[thread_position_in_grid]])
{
    uint index = pid * 4;                   // 4 is the number of control points per patch
    float totalTessellation = 0;
    
    for (int i = 0; i < 4; i++) {
        int pointAIndex = i;
        int pointBIndex = i + 1;
        if (pointAIndex == 3) {
            pointBIndex = 0;
        }
        int edgeIndex = pointBIndex;
        
        float cameraDistance = calc_distance(control_points[pointAIndex + index],
                                             control_points[pointBIndex + index],
                                             camera_position.xyz,
                                             modelMatrix);
        
        // sets a minimum edge factor of 4. The maximum depends upon the camera distance and
        // the maximum tessellation amount you specified for the terrain.
        float tessellation = max(4.0, terrainInfo.maxTessellation / cameraDistance);
        factors[pid].edgeTessellationFactor[edgeIndex] = tessellation;
        totalTessellation += tessellation;
    }
    
    factors[pid].insideTessellationFactor[0] = totalTessellation * 0.25;
    factors[pid].insideTessellationFactor[1] = totalTessellation * 0.25;
    y[pid] = y[pid] + 2;
}

[[patch(quad, 4)]] vertex VertexOut vertex_terrain(patch_control_point<ControlPoint>
                                                control_points [[stage_in]],
                                                constant float4x4 &mvp [[buffer(1)]],
                                                texture2d<float> heightMap0 [[texture(0)]],
                                                texture2d<float> heightMap1 [[texture(1)]],
                                                texture2d<float> heightMap2 [[texture(2)]],
                                                texture2d<float> heightMap3 [[texture(3)]],
                                                texture2d<float> heightMap4 [[texture(4)]],
                                                texture2d<float> heightMap5 [[texture(5)]],
                                                texture2d<float> heightMap6 [[texture(6)]],
                                                texture2d<float> heightMap7 [[texture(7)]],
                                                texture2d<float> heightMap8 [[texture(8)]],
                                                constant TerrainInfo &terrain [[buffer(6)]],
                                                uint patchID [[patch_id]],
                                                float2 patch_coord [[position_in_patch]])
{
    float u = patch_coord.x;    // 0..1
    float v = patch_coord.y;    // 0..1
    float2 top = mix(control_points[0].position.xz, control_points[1].position.xz, u);
    float2 bottom = mix(control_points[3].position.xz, control_points[2].position.xz, u);
    
    VertexOut out;
    float2 interpolated = mix(top, bottom, v);
    float4 position = float4(interpolated.x, 0.0, interpolated.y, 1.0); // -1..1
    
    float tx = terrain.size.x;
    float px = terrain.patches.x;
    float ox = 0.5*tx/px;
    
    float cx = 1.0/tx/0.8;  // heightmap is distributet on 4 of 5 patches 4/5 = 0.8
    float hmx = tx*0.8;
    float fx = tx/2.0;
    
    float posX = position.x + fx;
    float posZ = position.z + fx;

    constexpr sampler sample;
    float4 color;
    float2 xy;
    
    out.isEdge = false;

    if (posX > ox + hmx && posZ > ox + hmx) {
        xy = float2((posX - ox - hmx) * cx, (posZ - ox - hmx) * cx);
        color = heightMap2.sample(sample, xy);
        out.color = float4(0, 1, 0, 1); // green
        out.textureIndex = 2;
    }
    else if (posX > ox + hmx && posZ > ox) {
        xy = float2((posX - ox - hmx) * cx, (posZ - ox) * cx);
        color = heightMap5.sample(sample, xy);
        out.color = float4(1, 0, 1, 1);  // purple
        out.textureIndex = 5;
    }
    else if (posX > ox + hmx && posZ < ox) {
        xy = float2((posX - ox - hmx) * cx, (posZ - ox + hmx) * cx);
        color = heightMap8.sample(sample, xy);
        out.color = float4(0.9, 0.6, 0.3, 1); // orange
        out.textureIndex = 8;
    }
    else if (posX > ox && posZ > ox + hmx) {
        xy = float2((posX - ox) * cx, (posZ - ox - hmx) * cx);
        color = heightMap1.sample(sample, xy);
        out.color = float4(0, 0, 1, 1);  // blue
        out.textureIndex = 1;
    }
    else if (posX > ox && posZ > ox) {
        xy = float2((posX - ox) * cx, (posZ - ox) * cx);
        color = heightMap4.sample(sample, xy);
        out.color = float4(0.3, 0.6, 0.9, 1); // navy blue
        out.textureIndex = 4;
    }
    else if (posX > ox && posZ < ox) {
        xy = float2((posX - ox) * cx, (posZ - ox + hmx) * cx);
        color = heightMap7.sample(sample, xy);
        out.color = float4(0.5, 0.5, 0.5, 1); // gray
        out.textureIndex = 7;
    }
    else if (posX < ox && posZ > ox + hmx) {
        xy = float2((posX - ox + hmx) * cx, (posZ - ox - hmx) * cx);
        color = heightMap0.sample(sample, xy);
        out.color = float4(0.5, 0.7, 0.5, 1); // military green
        out.textureIndex = 0;
    }
    else if (posX < ox && posZ > ox) {
        xy = float2((posX - ox + hmx) * cx, (posZ - ox) * cx);
        color = heightMap3.sample(sample, xy);
        out.color = float4(0, 1, 1, 1);  // cyan
        out.textureIndex = 3;
    }
    else if (posX < ox && posZ < ox) {
        xy = float2((posX - ox + hmx) * cx, (posZ - ox + hmx) * cx);
        color = heightMap6.sample(sample, xy);
        out.color = float4(1, 1, 0, 1);  // yellow
        out.textureIndex = 6;
    }
    else {
        xy = float2(0.0);
        out.isEdge = true;
    }
    
    // meter is in the range -10000..10000
    float r = color.r * 256.0, g = color.g * 256.0, b = color.b * 256.0;   // convert from 0..1 values to 0..255
    float meters = -10000 + (r * 256 * 256 + g * 256 + b) * 0.1;     // for Zug area, this is between 415 and 950 m
    
    float aboveZugersee = (meters - 400) / 300;

    float height = aboveZugersee * terrain.height;
    position.y = height;
    
    out.position = mvp * position;
    
    out.uv = xy;
    return out;
}


fragment float4 fragment_terrain(VertexOut in [[stage_in]],
                              texture2d<float> satellite0 [[texture(0)]],
                              texture2d<float> satellite1 [[texture(1)]],
                              texture2d<float> satellite2 [[texture(2)]],
                              texture2d<float> satellite3 [[texture(3)]],
                              texture2d<float> satellite4 [[texture(4)]],
                              texture2d<float> satellite5 [[texture(5)]],
                              texture2d<float> satellite6 [[texture(6)]],
                              texture2d<float> satellite7 [[texture(7)]],
                              texture2d<float> satellite8 [[texture(8)]])
{
    if (in.isEdge)
        return float4(1, 0, 0, 1);
    
    texture2d<float> satelliteTexture;
    switch (in.textureIndex) {
        case 0:satelliteTexture = satellite0; break;
        case 1:satelliteTexture = satellite1; break;
        case 2:satelliteTexture = satellite2; break;
        case 3:satelliteTexture = satellite3; break;
        case 4:satelliteTexture = satellite4; break;
        case 5:satelliteTexture = satellite5; break;
        case 6:satelliteTexture = satellite6; break;
        case 7:satelliteTexture = satellite7; break;
        case 8:satelliteTexture = satellite8; break;
    }
    float brightness = 2.0;
    constexpr sampler sample(filter::linear, address::mirrored_repeat);
    float4 color = satelliteTexture.sample(sample, in.uv)*brightness;
    //return in.color;
    return color;
}
