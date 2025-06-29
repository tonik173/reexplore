//
//  CustomFilter.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 11.09.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import CoreImage

class CustomFilter: CIFilter
{
    enum Purpose {
        case none
        case terrain
    }
    
    internal lazy var libraryData: Data = {
        guard
            let url = Bundle.main.url(forResource: "CustomFilters.ci", withExtension: "metallib"),
            let data = try? Data(contentsOf: url) else {
                fatalError("Unable to load metallib")
        }
        
        return data
    }()
}
