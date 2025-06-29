//
//  ColorBarrierFilter.metal
//  Reexplore
//
//  Created by Toni Kaufmann on 11.09.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
#include <metal_stdlib>
using namespace metal;
#include <CoreImage/CoreImage.h>

extern "C"
{
    namespace coreimage
    {
        bool isMask(float v)
        {
            return v == 1;
        }
        
        float4 colorBarrierFilterKernel(sample_t s, float3 lc, float3 mc, float mask)
        {
            if (s.r >= lc[0] && s.r <= mc[0] &&
                s.g >= lc[1] && s.g <= mc[1] &&
                s.b >= lc[2] && s.b <= mc[2])
            {
                return isMask(mask) ? float4(1) : s;
            }
            return isMask(mask) ? float4(0,0,0,1) : float4(1,0,0,1);
        }
        
        
        float4 colorSameFilterKernel(sample_t s)
        {
            float3 ex = float3(230.0, 228.0, 224.0) / 255.0;
            float d1 = 3.0/255.0;
            if (s.r >= (ex[0] - d1) && s.r <= (ex[0] + d1) &&
                s.g >= (ex[1] - d1) && s.g <= (ex[1] + d1) &&
                s.b >= (ex[2] - d1) && s.b <= (ex[2] + d1))
            {
                return float4(0);
            }
            
            float d2 = 1.0/255.0;
            if (s.r >= (s.b - d2) && s.r <= (s.b + d2) &&
                s.r >= (s.g - d2) && s.r <= (s.g + d2) &&
                s.g >= (s.r - d2) && s.g <= (s.r + d2) &&
                s.g >= (s.b - d2) && s.g <= (s.b + d2) &&
                s.b >= (s.r - d2) && s.b <= (s.r + d2) &&
                s.b >= (s.g - d2) && s.b <= (s.g + d2)
                )
            {
                return s;
            }
            
            return float4(0);
        }
    }
}


