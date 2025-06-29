//
//  TerrainTile.metal
//  Reexplore
//
//  Created by Toni Kaufmann on 27.09.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
#include <metal_stdlib>
using namespace metal;
#include "Common.h"

struct VertexIn {
    float4 position [[attribute(0)]];
    float2 uv [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
    float4 shadowPositionStatic;
    float4 shadowPositionDynamic;
};

bool isColored(float4 color, float threshold)
{
    return color.r > threshold || color.g > threshold || color.b > threshold;
}

vertex VertexOut vertex_terrainTile(const VertexIn in [[stage_in]],
                                    constant Uniforms &uniforms [[buffer(BufferIndexUniforms)]])
{
    VertexOut out {
        .position = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix * in.position,
        .uv = in.uv,
        .shadowPositionStatic = uniforms.shadowMatrixStatic * uniforms.modelMatrix * in.position,
        .shadowPositionDynamic = uniforms.shadowMatrixDynamic * uniforms.modelMatrix * in.position,
    };
    
    return out;
}

float4 groundFog(float4 position, float4 color)
{
    float distance = position.z / position.w;
    float density = 0.003;
    float fog = 1.0 - clamp(exp(-density * distance), 0.0, 1.0);
    float4 fogColor = float4(0.85);
    color = mix(color, fogColor, fog);
    return color;
}

float shadow(depth2d<float> shadow, float4 position)
{
    if (!is_null_texture(shadow)) {
        constexpr sampler sample(filter::linear, address::clamp_to_edge);
        
        const float step = 1.0/shadow.get_width();
        
        float2 xy = position.xy;
        xy = xy * 0.5 + 0.5;
        xy.y = 1 - xy.y;
        
        const int edge = 1;
        float shadowCount = 0.0;
        float meassureCount = 0.0;
        for (float i = -edge;i <= edge; i++) {
            for (float j = -edge;j <= edge; j++) {
                xy.x += i*step;
                xy.y += j*step;
                if (xy.x > 0 && xy.y > 0 && xy.x < 1 && xy.y < 1) {
                    float shadow_sample = shadow.sample(sample, xy);
                    float current_sample = position.z / position.w;
                    if (current_sample > shadow_sample)
                        shadowCount++;
                    meassureCount++;
                }
            }
        }
        
        if (meassureCount > 0) {
            float shadow = shadowCount/meassureCount; // 1: full shadow, 0: no shadow
            return mix((1.0 - shadow), 1.0, 0.7);
        }
    }
    return 1.0;
}

fragment float4 fragment_terrainTile(VertexOut in [[stage_in]],
                                     texture2d<float> blended [[texture(TerrainTexture)]],
                                     texture2d<float> uploadTrack [[texture(UploadTrackTexture)]],
                                     texture2d<float> recordTrack [[texture(RecordTrackTexture)]],
                                     texture2d<float> info [[texture(InfoTexture)]],
                                     depth2d<float> shadowStatic [[texture(ShadowStaticTexture)]],
                                     depth2d<float> shadowDynamic [[texture(ShadowDynamicTexture)]])
{
    if (is_null_texture(blended))
        return float4(0.67, 0.8, 0.9, 1);
    
    constexpr sampler sample(filter::linear, address::clamp_to_edge);
    float4 blendedColor = blended.sample(sample, in.uv);
    float4 uploadTrackColor = uploadTrack.get_width() < 10 ? float4(0) : uploadTrack.sample(sample, in.uv);
    float4 recordTrackColor = recordTrack.get_width() < 10 ? float4(0) : recordTrack.sample(sample, in.uv);
    float4 infoColor = is_null_texture(info) ? float4(0) : info.sample(sample, in.uv);
    
    // fog
    float4 finalColor = groundFog(in.position, blendedColor);
    
    // shadow calculation
    float staticShadow = shadow(shadowStatic, in.shadowPositionStatic);
    finalColor *= staticShadow;
    
    float dynamicShadow = shadow(shadowDynamic, in.shadowPositionDynamic);
    finalColor *= dynamicShadow;

    // final mixing
    bool hasUploadTrackColor = isColored(uploadTrackColor, 50.0/256.0);
    bool hasRecordTrackColor = isColored(recordTrackColor, 50.0/256.0);
    bool hasInfoColor = isColored(infoColor, 50.0/256.0);

    if (hasRecordTrackColor)
        return 0.6 * finalColor + 0.4 * recordTrackColor;
    else if (hasUploadTrackColor)
        return 0.6 * finalColor + 0.4 * uploadTrackColor;
    else if (hasInfoColor)
        return 0.3 * finalColor + 0.7 * infoColor;
    else
        return finalColor;
}

