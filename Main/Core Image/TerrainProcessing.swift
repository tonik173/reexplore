//
//  TerrainProcessing.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 11.09.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import CoreImage

class TerrainProcessing
{
    internal lazy var woodsGround: CIImage = {
        guard
            let url = Bundle.main.url(forResource: "forest-ground", withExtension: "jpg"),
            let ciimage = CIImage(contentsOf: url) else {
                fatalError("Unable to load forest ground")
        }
        return ciimage
    }()
    
    internal lazy var forestGround: CIImage = {
        guard
            let url = Bundle.main.url(forResource: "grass-dark", withExtension: "jpg"),
            let ciimage = CIImage(contentsOf: url) else {
                fatalError("Unable to grass dark ground")
        }
        return ciimage
    }()
    
    internal lazy var waterGround: CIImage = {
        guard
            let url = Bundle.main.url(forResource: "water-blue", withExtension: "jpg"),
            let ciimage = CIImage(contentsOf: url) else {
                fatalError("Unable to grass water ground")
        }
        return ciimage
    }()
    
    internal lazy var grassGround: CIImage = {
        guard
            let url = Bundle.main.url(forResource: "grass", withExtension: "png"),
            let ciimage = CIImage(contentsOf: url) else {
                fatalError("Unable to grass ground")
        }
        return ciimage
    }()
    
    internal lazy var lawnGround: CIImage = {
        guard
            let url = Bundle.main.url(forResource: "lawn", withExtension: "jpg"),
            let ciimage = CIImage(contentsOf: url) else {
                fatalError("Unable to grass ground")
        }
        return ciimage
    }()
    
    typealias TextureParts = (mask: CIImage, cover: CIImage)
    
    func process(image: CIImage) -> CIImage
    {
        let length = UInt16(image.extent.size.width)
        
        // creates masks as well as the textures for the different part of the street map
        let populations: [PopulationType] = [.woods, .water, .forest, .gras, .lawn]
        var parts = [TextureParts]()
        for population in populations {
            if let mask = self.mask(image: image, population: population) {
                let cover = self.createTexture(withLength: length, population: population)
                let elem = (mask: mask, cover: cover)
                parts.append(elem)
            }
        }
        
        // blends the textures obto the street maps by using the masks
        var terrainImage = image
        for part in parts {
            let mask = self.erode(part.mask)
            let parameters = ["inputBackgroundImage": terrainImage,
                              "inputImage": part.cover,
                              "inputMaskImage": mask ]
            if let filter = CIFilter(name: "CIBlendWithMask", parameters: parameters) {
                if let outputImage = filter.outputImage {
                    terrainImage = outputImage
                }
            }
        }
        
        // extracts the street/creek/text ans gravel layers and merges them with the textured image
        // (erosion also effects the streets and texts therefore its blenden again with the final image)
        let streets = self.streetsFilter(image: image)
        let addParams = ["inputBackgroundImage":  terrainImage]
        let finalImage = streets.applyingFilter("CISourceOverCompositing", parameters: addParams)
        
        /*
        if let cgImage = ImageHelpers.cgImage(fromCIImage: streets) {
            let path = PathHelpers.debugPath(forFilename: "street.png").path
            ImageHelpers.write(toFile: path, image: cgImage)
        }
        if let cgImage = ImageHelpers.cgImage(fromCIImage: terrainImage) {
            let path = PathHelpers.debugPath(forFilename: "terrain.png").path
            ImageHelpers.write(toFile: path, image: cgImage)
        }
        if let cgImage = ImageHelpers.cgImage(fromCIImage: finalImage) {
            let path = PathHelpers.debugPath(forFilename: "final.png").path
            ImageHelpers.write(toFile: path, image: cgImage)
        }
        */
        
        return finalImage
    }
    
    fileprivate func erode(_ image: CIImage) -> CIImage
    {
        let c:CGFloat = 0
        let f:CGFloat = 1
        let coeffs: [CGFloat] = [ f, c, f,
                                  c ,c ,c,
                                  f, c, f ]
        let k = CIVector(values: coeffs, count: coeffs.count)
        let parameters = ["inputWeights": k] as [String:Any]
        
        var working = image
        for _ in 0..<1 {
            working = working.applyingFilter("CIConvolution3X3", parameters: parameters)
        }
        
        return working
    }
    
    func createTexture(withLength length: UInt16, population: PopulationType) -> CIImage
    {
        let textureImage = self.texture(forPopulation: population)
        let step: UInt16 = 64
        let textureScale = CGFloat(step)/textureImage.extent.size.width
        
        let rowSize = CGSize(width: Int(length), height: Int(length))
        var image = CIImage(cgImage: ImageHelpers.createEmptyImage(withSize: rowSize)!)
        var x: UInt16 = 0
        var y: UInt16 = 0
        var hFlip = false
        var vFlip = false
        
        let scaleTransform = CGAffineTransform(scaleX: CGFloat(textureScale), y: CGFloat(textureScale))
        let scaleParams = ["inputTransform":  scaleTransform]
        let scaled = textureImage.applyingFilter("CIAffineTransform", parameters: scaleParams)
        
        while y < length {
            while x < length {
                var filtered = scaled
                
                if hFlip {
                    let flip = CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: CGFloat(step), ty: 0)
                    let flipParams = ["inputTransform":  flip]
                    filtered = filtered.applyingFilter("CIAffineTransform", parameters: flipParams)
                }
                hFlip = !hFlip
                
                if vFlip {
                    let flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: CGFloat(step))
                    let flipParams = ["inputTransform":  flip]
                    filtered = filtered.applyingFilter("CIAffineTransform", parameters: flipParams)
                }
                
                let transform = CGAffineTransform(translationX: CGFloat(x), y: CGFloat(y))
                let transformParams = ["inputTransform":  transform]
                filtered = filtered.applyingFilter("CIAffineTransform", parameters: transformParams)
                
                let addParams = ["inputBackgroundImage":  image]
                image = filtered.applyingFilter("CISourceOverCompositing", parameters: addParams)
                
                x = x + step
            }
            vFlip = !vFlip
            hFlip = false
            x = 0
            y = y + step
        }
        return image
    }
    
    fileprivate func texture(forPopulation population: PopulationType) -> CIImage
    {
        switch population {
        case .woods: return woodsGround
        case .forest: return forestGround
        case .water: return waterGround
        case .gras: return grassGround
        case .lawn: return lawnGround
        default:
            return forestGround
        }
    }
    
    fileprivate func mask(image: CIImage, population: PopulationType) -> CIImage?
    {
        let filter = ColorBarrierFilter()
        filter.inputImage = image
        let edges = self.vector(forPopulation: population)
        filter.minColor = edges[0]
        filter.maxColor = edges[1]
        return filter.outputImage
    }
    
    fileprivate func streetsFilter(image: CIImage) -> CIImage
    {
        var processedImage = image
        let filter = ColorSameFilter()
        filter.inputImage = image
        if let outputImage = filter.outputImage {
            processedImage = outputImage
        }
        return processedImage
    }
    
    fileprivate func vector(forPopulation population: PopulationType) -> [CIVector]
    {
        switch population {
        case .forest:
            let b = TerrainHelpers.forestBoundaries
            return [ CIVector(x: CGFloat(b.min.red)/255.0, y: CGFloat(b.min.green)/255.0, z: CGFloat(b.min.blue)/255.0),
                     CIVector(x: CGFloat(b.max.red)/255.0, y: CGFloat(b.max.green)/255.0, z: CGFloat(b.max.blue)/255.0)]
        case .woods:
            let b = TerrainHelpers.woodsBoundaries
            return [ CIVector(x: CGFloat(b.min.red)/255.0, y: CGFloat(b.min.green)/255.0, z: CGFloat(b.min.blue)/255.0),
                     CIVector(x: CGFloat(b.max.red)/255.0, y: CGFloat(b.max.green)/255.0, z: CGFloat(b.max.blue)/255.0)]
        case .water:
            let b = TerrainHelpers.waterBoundaries
            return [ CIVector(x: CGFloat(b.min.red)/255.0, y: CGFloat(b.min.green)/255.0, z: CGFloat(b.min.blue)/255.0),
                     CIVector(x: CGFloat(b.max.red)/255.0, y: CGFloat(b.max.green)/255.0, z: CGFloat(b.max.blue)/255.0)]
        case .gras:
            let b = TerrainHelpers.grassBoundaries
            return [ CIVector(x: CGFloat(b.min.red)/255.0, y: CGFloat(b.min.green)/255.0, z: CGFloat(b.min.blue)/255.0),
                     CIVector(x: CGFloat(b.max.red)/255.0, y: CGFloat(b.max.green)/255.0, z: CGFloat(b.max.blue)/255.0)]
        case .lawn:
            let b = TerrainHelpers.lawnBoundaries
            return [ CIVector(x: CGFloat(b.min.red)/255.0, y: CGFloat(b.min.green)/255.0, z: CGFloat(b.min.blue)/255.0),
                     CIVector(x: CGFloat(b.max.red)/255.0, y: CGFloat(b.max.green)/255.0, z: CGFloat(b.max.blue)/255.0)]
        case .street:
            let b = TerrainHelpers.streetBoundaries
            return [ CIVector(x: CGFloat(b.min.red)/255.0, y: CGFloat(b.min.green)/255.0, z: CGFloat(b.min.blue)/255.0),
                     CIVector(x: CGFloat(b.max.red)/255.0, y: CGFloat(b.max.green)/255.0, z: CGFloat(b.max.blue)/255.0)]
            
        default:
            return [CIVector(x: 0),CIVector(x: 0)]
        }
    }
}
