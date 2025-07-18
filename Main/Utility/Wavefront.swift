//
//  Wavefront.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 31.08.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import Foundation
import MetalKit

class Wavefront
{
    static func export(positions: [float3], texCoords: [float2], normals: [float3], indices: [UInt32])
    {
        let objfile = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("terrain.obj")
        do {
            if FileManager.default.fileExists(atPath: objfile.path) {
                try FileManager.default.removeItem(at: objfile)
            }
            
            try "o Terrain\n".write(to: objfile, atomically: true, encoding: String.Encoding.utf8)
            let filehandle = try FileHandle(forWritingTo: objfile)
            
            // positions
            for p in 0 ..< positions.count {
                let str = "v \(positions[p].x) \(positions[p].y) \(positions[p].z)\n"
                if let data = str.data(using: String.Encoding.utf8) { filehandle.write(data) }
            }
            
            // texture coords
         var t = 0
            while t < texCoords.count {
                let str = "vt \(texCoords[t]) \(texCoords[t+1])\n"
                if let data = str.data(using: String.Encoding.utf8) { filehandle.write(data) }
                t = t + 2
            }
            
            // normals
            var n = 0
            while n < normals.count {
                let str = "vn \(normals[n]) \(normals[n+1]) \(normals[n+2])\n"
                if let data = str.data(using: String.Encoding.utf8) { filehandle.write(data) }
                n = n + 3
            }
            
            // indices
            var i = 0
            while i < indices.count {
                let str1 = "f \(indices[i]+1) \(indices[i+1]+1) \(indices[i+2]+1)\n"
                if let data = str1.data(using: String.Encoding.utf8) { filehandle.write(data) }
                let str2 = "f \(indices[i+3]+1) \(indices[i+4]+1) \(indices[i+5]+1)\n"
                if let data = str2.data(using: String.Encoding.utf8) { filehandle.write(data) }
                i = i + 6
            }
            
            filehandle.closeFile()
            print("\(objfile.path) exported")
        }
        catch {
            print("Failed to export \(objfile.path)")
        }
    }
}
