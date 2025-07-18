//
//  InfoTile.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 09.09.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import Foundation
import Metal
import CoreImage
import CoreText

struct InfoTile
{
    fileprivate static let dimension = 256
    
    static func render(device: MTLDevice, tile: Tile, maxLevel: UInt8) -> [MTLTexture]
    {
        var textures: [MTLTexture] = []
        for i in 0...maxLevel {
            if let texture = self.render(device: device, tile: tile, level: i) {
                textures.append(texture)
            }
        }
        return textures
    }
    
    fileprivate static func render(device: MTLDevice, tile: Tile, level: UInt8) -> MTLTexture?
    {
        var texture: MTLTexture? = .none
        let bufferSize = 4 * dimension * dimension
        let rawData = UnsafeMutablePointer<UInt8>.allocate(capacity:bufferSize)
        if let context = CGContext(data: rawData,
                                   width: dimension, height: dimension,
                                   bitsPerComponent: 8, bytesPerRow: 4 * dimension,
                                   space: CGColorSpaceCreateDeviceRGB(),
                                   bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
            
            let rect = CGRect(x: 0, y: 0, width: dimension, height: dimension)
            context.setLineWidth(0.5)
            context.setFillColor(Globals.Colors.purple)
            context.setStrokeColor(Globals.Colors.yellow)
            context.setLineCap(.round)

            // background
            context.clear(rect)

            // boundaries
            context.addRect(rect)
            context.drawPath(using: .stroke)

            // set label
            context.textMatrix = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 128)
            let font = CTFontCreateWithName("Helvetica" as CFString, 13, nil)
            var pos = CGPoint(x: 40, y: 0)
            let text = "\(tile.description)-\(level)"
            for c in text {
                let glyphname = self.glyphname(for: c)
                var glyph = CTFontGetGlyphWithName(font, glyphname)
                CTFontDrawGlyphs(font, &glyph, &pos, 1, context)
                pos.x = pos.x + 11
            }
            
            // rendering
            if let cgImage = context.makeImage() {
                context.draw(cgImage, in: rect)
                
                // create texture
                let textureDescriptor = MTLTextureDescriptor()
                textureDescriptor.pixelFormat = .rgba8Unorm
                textureDescriptor.width = cgImage.width
                textureDescriptor.height = cgImage.height
                texture = device.makeTexture(descriptor: textureDescriptor)
                let region = MTLRegionMake2D(0, 0, cgImage.width, cgImage.height)
                texture?.replace(region: region, mipmapLevel: 0, withBytes: rawData, bytesPerRow: 4 * cgImage.width)
            }
        }
        rawData.deallocate()
        return texture
    }
    
    fileprivate static func glyphname(for c: Character) -> CFString
    {
        switch c {
        case "0": return "zero" as CFString
        case "1": return "one" as CFString
        case "2": return "two" as CFString
        case "3": return "three" as CFString
        case "4": return "four" as CFString
        case "5": return "five" as CFString
        case "6": return "six" as CFString
        case "7": return "seven" as CFString
        case "8": return "eight" as CFString
        case "9": return "nine" as CFString
        case "x": return "x" as CFString
        case "y": return "y" as CFString
        case "z": return "z" as CFString
        default: return "hyphen" as CFString
        }
    }
}
