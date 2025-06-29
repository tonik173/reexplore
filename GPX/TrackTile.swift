//
//  TrackTile.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 08.09.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import Foundation
import Metal
import MetalKit
import CoreImage

class TrackTile : CustomStringConvertible
{
    let tile: Tile
    var texture: MTLTexture?
    
    init(tile: Tile)
    {
        self.tile = tile
    }
    
    var description: String { return "\(self.tile.description)"}
    
    func createTexture(forCgImage cgImage: CGImage, device: MTLDevice)
    {
        // if let _ = self.texture { return } // no need to create texture if it alredy exists
        
        do {
            let textureLoader = MTKTextureLoader(device: Renderer.device)
            let options: [MTKTextureLoader.Option : Any] = [MTKTextureLoader.Option.SRGB: 0,
                                                            MTKTextureLoader.Option.allocateMipmaps: 0,
                                                            MTKTextureLoader.Option.textureUsage: MTLTextureUsage.shaderRead.rawValue,
                                                            MTKTextureLoader.Option.origin: MTKTextureLoader.Origin.topLeft]
            self.texture = try textureLoader.newTexture(cgImage: cgImage, options:options)
            
            let path = PathHelpers.tracksImagesPath(forTile: self.tile).path
            ImageHelpers.write(toFile: path, image: cgImage)
        }
        catch let error as NSError {
            fatalError(error.localizedDescription)
        }
    }
}
