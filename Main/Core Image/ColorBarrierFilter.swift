//
//  ColorBarrierFilter.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 11.09.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import CoreImage

class ColorBarrierFilter: CustomFilter
{
    private lazy var kernel: CIColorKernel = {
        guard let kernel = try? CIColorKernel(functionName: "colorBarrierFilterKernel", fromMetalLibraryData: libraryData) else {
            fatalError("Unable to create the CIColorKernel for colorBarrierFilterKernel")
        }
        
        return kernel
    }()
    
    var inputImage: CIImage?
    var minColor = CIVector(x: 0, y: 0, z: 0)
    var maxColor = CIVector(x: 1, y: 1, z: 1)
    var mask = CGFloat(1)
    
    override var outputImage: CIImage? {
        guard let inputImage = inputImage else { return .none }
        
        return kernel.apply(extent: inputImage.extent,
                            roiCallback: { (index, rect) -> CGRect in
                                return rect
        }, arguments: [inputImage, minColor, maxColor, mask])
    }
    
}
