//
//  SimpleModel.metal
//  Reexplore
//
//  Created by Toni Kaufmann on 05.02.21.
//  Copyright © 2021 n3xd software studios ag. All rights reserved.
//
#include <metal_stdlib>
using namespace metal;
#include "Common.h"

struct VertexIn {
    float4 position [[attribute(Position)]];
    float3 normal [[attribute(Normal)]];
    float2 uv [[attribute(UV)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 worldPosition;
    float3 worldNormal;
    float2 uv;
};

float4 fogSimple(float4 position, float4 color)
{
    float distance = position.z / position.w;
    float density = 0.003;
    float fog = 1.0 - clamp(exp(-density * distance), 0.0, 1.0);
    float4 fogColor = float4(0.9);
    color = mix(color, fogColor, fog);
    return color;
}

vertex VertexOut vertex_simple(const VertexIn vertexIn [[stage_in]],
                             constant Instances *instances [[buffer(BufferIndexInstances)]],
                             uint instanceID [[instance_id]],
                             constant Uniforms &uniforms [[buffer(BufferIndexUniforms)]])
{
    float4 position = vertexIn.position;
    float4 normal = float4(vertexIn.normal, 0);
        
    Instances instance = instances[instanceID];
    VertexOut out {
        .position = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix * instance.modelMatrix * position,
        .worldPosition = (uniforms.modelMatrix * instance.modelMatrix * position).xyz,
        .worldNormal = uniforms.normalMatrix * instance.normalMatrix * normal.xyz,
        .uv = vertexIn.uv,
    };
    
    return out;
}

fragment float4 fragment_simple(VertexOut in [[stage_in]],
                             sampler textureSampler [[sampler(0)]],
                             constant Material &material [[buffer(BufferIndexMaterials)]],
                             constant FragmentUniforms &fragmentUniforms [[buffer(BufferIndexFragmentUniforms)]],
                             texturecube<float> skybox [[texture(BufferIndexSkybox)]],
                             texturecube<float> skyboxDiffuse [[texture(BufferIndexSkyboxDiffuse)]],
                             texture2d<float> brdfLut [[texture(BufferIndexBRDFLut)]])
{
    float3 baseColor = material.baseColor;
    float metallic = material.metallic;
    float roughness = material.roughness;
    float ambientOcclusion = 1.0;
    float3 normal = in.worldNormal;

    normal = normalize(normal);
    float4 diffuse = skyboxDiffuse.sample(textureSampler, normal);
    diffuse = mix(pow(diffuse, 0.3), diffuse, metallic);
    
    float3 viewDirection = in.worldPosition.xyz - fragmentUniforms.cameraPosition;
    float3 textureCoordinates = reflect(viewDirection, normal);
    
    constexpr sampler s(filter::linear, mip_filter::linear);
    float3 prefilteredColor = skybox.sample(s, textureCoordinates, level(roughness * 10)).rgb;
    
    float nDotV = saturate(dot(normal, normalize(-viewDirection)));
    float2 envBRDF = brdfLut.sample(s, float2(roughness, nDotV)).rg;
    
    float3 f0 = mix(0.04, baseColor.rgb, metallic);
    float3 specularIBL = f0 * envBRDF.r + envBRDF.g;
    
    float3 specular = prefilteredColor * specularIBL;
    float4 color = diffuse * float4(baseColor, 1) + float4(specular, 1);
    color *= ambientOcclusion;
    
    color = fogSimple(in.position, color);
    
    return color;
}


