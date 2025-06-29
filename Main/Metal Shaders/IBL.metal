//
//  IBL.metal
//  Reexplore
//
//  Created by Toni Kaufmann on 16.06.2020.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
#include <metal_stdlib>
using namespace metal;
#include "Common.h"

constant bool hasColorTexture [[function_constant(0)]];
constant bool hasNormalTexture [[function_constant(1)]];
constant bool hasRoughnessTexture [[function_constant(2)]];
constant bool hasMetallicTexture [[function_constant(3)]];
constant bool hasAOTexture [[function_constant(4)]];

struct VertexOut {
    float4 position [[position]];
    float3 worldPosition;
    float3 worldNormal;
    float2 uv;
    float3 worldTangent;
    float3 worldBitangent;
};

float4 fog(float4 position, float4 color)
{
    float distance = position.z / position.w;
    float density = 0.002;
    float fog = 1.0 - clamp(exp(-density * distance), 0.0, 1.0);
    float4 fogColor = float4(0.9);
    color = mix(color, fogColor, fog);
    return color;
}

fragment float4 fragment_IBL(VertexOut in [[stage_in]],
                             sampler textureSampler [[sampler(0)]],
                             constant Material &material [[buffer(BufferIndexMaterials)]],
                             constant FragmentUniforms &fragmentUniforms [[buffer(BufferIndexFragmentUniforms)]],
                             texture2d<float> baseColorTexture [[texture(BaseColorTexture), function_constant(hasColorTexture)]],
                             texture2d<float> normalTexture [[texture(NormalTexture), function_constant(hasNormalTexture)]],
                             texture2d<float> roughnessTexture [[texture(RoughnessTexture), function_constant(hasRoughnessTexture)]],
                             texture2d<float> metallicTexture [[texture(MetallicTexture), function_constant(hasMetallicTexture)]],
                             texture2d<float> aoTexture [[texture(AOTexture), function_constant(hasAOTexture)]],
                             texturecube<float> skybox [[texture(BufferIndexSkybox)]],
                             texturecube<float> skyboxDiffuse [[texture(BufferIndexSkyboxDiffuse)]],
                             texture2d<float> brdfLut [[texture(BufferIndexBRDFLut)]] )
{
    // extract color
    float3 baseColor;
    if (hasColorTexture) {
        float4 color = baseColorTexture.sample(textureSampler, in.uv * fragmentUniforms.tiling);
        if (color.a < 0.2) { discard_fragment(); }
        baseColor = color.rgb;
    }
    else {
        baseColor = material.baseColor;
    }
    
    // extract metallic
    float metallic;
    if (hasMetallicTexture) {
        metallic = metallicTexture.sample(textureSampler, in.uv).r;
    }
    else {
        metallic = material.metallic;
    }
    
    // extract roughness
    float roughness;
    if (hasRoughnessTexture) {
        roughness = roughnessTexture.sample(textureSampler, in.uv).r;
    }
    else {
        roughness = material.roughness;
    }
    
    // extract ambient occlusion
    float ambientOcclusion;
    if (hasAOTexture) {
        ambientOcclusion = aoTexture.sample(textureSampler, in.uv).r;
    }
    else {
        ambientOcclusion = 1.0;
    }
    
    // normal map
    float3 normal;
    if (hasNormalTexture) {
        float3 normalValue = normalTexture.sample(textureSampler, in.uv * fragmentUniforms.tiling).xyz * 2.0 - 1.0;
        normal = in.worldNormal * normalValue.z + in.worldTangent * normalValue.x + in.worldBitangent * normalValue.y;
        
    }
    else {
        normal = in.worldNormal;
    }
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
    
    color = fog(in.position, color);
    return color;
}


