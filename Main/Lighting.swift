//
//  Lighting.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 16.06.2020.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import Foundation

struct Lighting
{
    // Lights
    let sunlight: Light = {
        var light = Lighting.buildDefaultLight()
        light.position = [3, 2, 0]
        return light
    }()
    let lights: [Light]
    let count: UInt32
    
    init()
    {
        lights = [sunlight]
        count = UInt32(lights.count)
    }
    
    static func buildDefaultLight() -> Light
    {
        var light = Light()
        light.position = [0, 0, 0]
        light.color = [1, 1, 1]
        light.specularColor = [1, 1, 1]
        light.intensity = 0.6
        light.attenuation = float3(1, 0, 0)
        light.type = Sunlight
        return light
    }
}
