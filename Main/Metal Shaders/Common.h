//
//  Common.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 16.06.2020.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
#ifndef Common_h
#define Common_h
#import <simd/simd.h>

typedef struct {
    matrix_float4x4 modelMatrix;
    matrix_float4x4 viewMatrix;
    matrix_float4x4 projectionMatrix;
    matrix_float3x3 normalMatrix;
    matrix_float4x4 shadowMatrixStatic;
    matrix_float4x4 shadowMatrixDynamic;
} Uniforms;

typedef enum {
    unused = 0,
    Sunlight = 1,
    Spotlight = 2,
    Pointlight = 3,
    Ambientlight = 4
} LightType;

typedef struct {
    vector_float3 position;
    vector_float3 color;
    vector_float3 specularColor;
    float intensity;
    vector_float3 attenuation;
    LightType type;
    float coneAngle;
    vector_float3 coneDirection;
    float coneAttenuation;
} Light;

typedef struct {
    uint lightCount;
    vector_float3 cameraPosition;
    uint tiling;
} FragmentUniforms;

typedef enum {
    Position = 0,
    Normal = 1,
    UV = 2,
    Tangent = 3,
    Bitangent = 4,
    Color = 5,
    Joints = 6,
    Weights = 7
} Attributes;

typedef enum {
    BaseColorTexture = 0,
    NormalTexture = 1,
    RoughnessTexture = 2,
    MetallicTexture = 3,
    AOTexture = 4,
    UploadTrackTexture = 5,
    RecordTrackTexture = 6,
    InfoTexture = 7,
    TerrainTexture = 8,
    ShadowStaticTexture = 9,
    ShadowDynamicTexture = 10,
} Textures;

typedef enum {
    BufferIndexVertices = 0,
    BufferIndexUniforms = 11,
    BufferIndexLights = 12,
    BufferIndexFragmentUniforms = 13,
    BufferIndexMaterials = 14,
    BufferIndexInstances = 15,
    BufferIndexModelParams = 17,
    BufferIndexSkybox = 20,
    BufferIndexSkyboxDiffuse = 21,
    BufferIndexBRDFLut = 22
} BufferIndices;

typedef struct {
    vector_float3 baseColor;
    vector_float3 specularColor;
    float roughness;
    float metallic;
    vector_float3 ambientOcclusion;
    float shininess;
} Material;

struct Instances {
    matrix_float4x4 modelMatrix;
    matrix_float3x3 normalMatrix;
};

typedef struct {
    matrix_float4x4 modelMatrix;
    uint tiling;
} ModelParams;

#endif
