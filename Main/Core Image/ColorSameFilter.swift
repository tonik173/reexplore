//
//  ColorSameFilter.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 15.09.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import CoreImage

class ColorSameFilter: CustomFilter
{
    private lazy var kernel: CIColorKernel = {
        guard let kernel = try? CIColorKernel(functionName: "colorSameFilterKernel", fromMetalLibraryData: libraryData) else {
            fatalError("Unable to create the CIColorKernel for colorSameFilterKernel")
        }
        
        return kernel
    }()
    
    var inputImage: CIImage?
    
    override var outputImage: CIImage? {
        guard let inputImage = inputImage else { return .none }
        
        return kernel.apply(extent: inputImage.extent,
                            roiCallback: { (index, rect) -> CGRect in
                                return rect
        }, arguments: [inputImage])
    }
}
