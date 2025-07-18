//
//  ImageHelpers.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 19.06.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import Foundation
import MetalKit

struct ImageHelpers
{
    typealias Color = (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8)
    typealias ImageSourceInfo = (url: URL, scale: Float, alpha: Float, filter: CustomFilter.Purpose)
    
    static func cgImage(fromURL url: URL) -> CGImage?
    {
        let ciimage = CIImage(contentsOf: url, options: [CIImageOption.applyOrientationProperty:true])
        if let cgImage = cgImage(fromCIImage: ciimage!) {
            if let context = CGContext(data: nil,
                                       width: cgImage.width,
                                       height: cgImage.height,
                                       bitsPerComponent: cgImage.bitsPerComponent,
                                       bytesPerRow: cgImage.bytesPerRow,
                                       space: cgImage.colorSpace!,
                                       bitmapInfo: cgImage.bitmapInfo.rawValue) {
                
                let flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: CGFloat(cgImage.height))
                context.concatenate(flip)
                context.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))
                let output = context.makeImage()
                return output
            }
        }
        return .none
    }
    
    static func createEmptyImage(withSize size: CGSize) -> CGImage?
    {
        var image: CGImage? = .none
        let bufferSize = 4 * Int(size.width) * Int(size.height)
        let rawData = UnsafeMutablePointer<UInt8>.allocate(capacity:bufferSize)
        if let context = CGContext(data: rawData,
                                   width: Int(size.width), height: Int(size.height),
                                   bitsPerComponent: 8, bytesPerRow: 4 * Int(size.width),
                                   space: CGColorSpaceCreateDeviceRGB(),
                                   bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
            
            let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            context.setFillColor(Globals.Colors.purple)
            context.addRect(rect)
            context.drawPath(using: .fill)
            
            // rendering
            if let cgImage = context.makeImage() {
                context.draw(cgImage, in: rect)
                image = cgImage
            }
        }
        rawData.deallocate()
        return image
    }
    
    static func loadTexture(sources: [ImageSourceInfo], device: MTLDevice) -> MTLTexture?
    {
        var composed: CIImage? = .none
        for source in sources {
            if source.alpha > 0 {
                if let ciimage = CIImage(contentsOf: source.url, options: [.applyOrientationProperty:true, .colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!]) {
                    
                    // terrain processing
                    var inputImage = ciimage
                    if source.filter == CustomFilter.Purpose.terrain {
                        let terrainProcessor = TerrainProcessing()
                        inputImage = terrainProcessor.process(image: ciimage)
                    }
                    
                    // alpha channel setting
                    let alpha = CIVector(x: 0, y: 0, z: 0, w: CGFloat(source.alpha))
                    let alphaParams = ["inputAVector":  alpha]
                    let filteredAlpha = inputImage.applyingFilter("CIColorMatrix", parameters: alphaParams)
                    
                    // scaling
                    let scale = CGAffineTransform(scaleX: CGFloat(source.scale), y: CGFloat(source.scale))
                    let scaleParams = ["inputTransform":  scale]
                    let filteredScale = filteredAlpha.applyingFilter("CIAffineTransform", parameters: scaleParams)
                    
                    // comosing
                    if let image = composed {
                        composed = filteredScale.composited(over: image)
                    }
                    else {
                        composed = filteredScale
                    }
                }
            }
        }
        
        if let ciimage = composed {
            if let cgImage = cgImage(fromCIImage: ciimage) {
                return createTexture(forImage: cgImage, device: device)
            }
        }
        
        return .none
    }
    
    static func loadTexture(url: URL, device: MTLDevice) -> MTLTexture?
    {
        if let ciimage = CIImage(contentsOf: url, options: [.applyOrientationProperty:true, .colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!]) {
            if let cgImage = cgImage(fromCIImage: ciimage) {
                return createTexture(forImage: cgImage, device: device)
            }
        }
        return .none
    }
    
    static func createTexture(forImage cgImage: CGImage, device: MTLDevice) -> MTLTexture?
    {
        let context = CGContext(data: nil,
                                width: cgImage.width,
                                height: cgImage.height,
                                bitsPerComponent: cgImage.bitsPerComponent,
                                bytesPerRow: cgImage.bytesPerRow,
                                space: cgImage.colorSpace!,
                                bitmapInfo: cgImage.bitmapInfo.rawValue)
        
        let flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: CGFloat(cgImage.height))
        context?.concatenate(flip)
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))
        
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.pixelFormat = .rgba8Unorm
        textureDescriptor.width = cgImage.width
        textureDescriptor.height = cgImage.height
        
        let texture = device.makeTexture(descriptor: textureDescriptor)
        
        let region = MTLRegionMake2D(0, 0, cgImage.width, cgImage.height)
        
        guard let data = context?.data else {
            print("No data in context.")
            return .none
        }
        texture?.replace(region: region, mipmapLevel: 0, withBytes: data, bytesPerRow: 4 * cgImage.width)
        return texture
    }
    
    static func cgImage(fromCIImage inputImage: CIImage) -> CGImage?
    {
        let outputColorSpace = inputImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CIContext(options: [
            .workingColorSpace: outputColorSpace,
            .workingFormat: CIFormat.BGRA8,
            .outputColorSpace: outputColorSpace
        ])
        if let cgImage = context.createCGImage(inputImage, from: inputImage.extent) {
            return cgImage
        }
        return .none
    }
    
    static func cgImage(for name: String) -> CGImage?
    {
        #if os(iOS)
        
        if let image = UIImage(named: name) {
            return image.cgImage
        }
        
        #elseif os(macOS)
        
        let image = NSImage(named: name)
        if let image = image {
            var imageRect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
            return image.cgImage(forProposedRect: &imageRect, context: nil, hints: nil)
        }
        
        #endif
        
        return .none
    }
    
    static func color(fromCGImage cgImage:CGImage, at position: CGPoint) -> Color
    {
        let x = Int(position.x)
        let y = Int(position.y)
        
        return color(fromCGImage: cgImage, atX: x, atY: y)
    }
    
    static func color(fromCGImage cgImage:CGImage, atX x: Int, atY y: Int) -> Color
    {
        if let pixelData = cgImage.dataProvider?.data {
            let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
            let pixelInfo: Int = (Int(cgImage.width) * y + x) * Int(4)
            let red = data[pixelInfo]
            let green = data[pixelInfo+1]
            let blue = data[pixelInfo+2]
            let alpha = data[pixelInfo+3]
            return Color(red: red, green: green, blue: blue, alpha: alpha)
        }
        return Color(red: 0, green: 0, blue: 0, alpha: 0)
    }
    
    static func color(fromTexture texture: MTLTexture, at position: CGPoint) -> Color
    {
        let x = Int(position.x)
        let y = Int(position.y)
        
        return color(fromTexture: texture, atX: x, atY: y)
    }
    
    static func color(fromTexture texture: MTLTexture, atX x: Int, atY y: Int) -> Color
    {
        let region = MTLRegionMake2D(x, y, 1, 1)
        let bytesPerRow = MemoryLayout<UInt8>.size * texture.width * 4
        
        var texelArray = Array<UInt8>(repeating: 0, count: 4)
        texelArray.withUnsafeMutableBytes { texelArrayPtr in
            texture.getBytes(texelArrayPtr.baseAddress!, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        }
        
        return Color(red: texelArray[0], green: texelArray[1], blue: texelArray[2], alpha: texelArray[3])
    }
    
    static func byteValue(fromTexture texture: MTLTexture, atX x: Int, atY y: Int) -> UInt8
    {
        let region = MTLRegionMake2D(x, y, 1, 1)
        let bytesPerRow = MemoryLayout<UInt8>.size * texture.width
        
        var texelArray = Array<UInt8>(repeating: 0, count: 1)
        texelArray.withUnsafeMutableBytes { texelArrayPtr in
            texture.getBytes(texelArrayPtr.baseAddress!, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        }
        
        return texelArray[0]
    }
    
    static func data(fromCGImage cgImage: CGImage) -> Data?
    {
        guard let mutableData = CFDataCreateMutable(nil, 0),
            let destination = CGImageDestinationCreateWithData(mutableData, "public.png" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return mutableData as Data
    }
    
    static func write(toFile path: String, image: CGImage)
    {
        if let data = ImageHelpers.data(fromCGImage: image) as NSData? {
            do {
                if FileManager.default.fileExists(atPath: path) {
                    try FileManager.default.removeItem(atPath: path)
                }
                try data.write(toFile: path)
            }
            catch let error as NSError {
                fatalError(error.localizedDescription)
            }
        }
    }
}


