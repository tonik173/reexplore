//
//  TerrainHelpers.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 10.09.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import Foundation

enum PopulationType: CaseIterable
{
    case unknown
    case water
    case street
    case gras
    case woods
    case forest
    case buildings
    case lawn
    case creek
    case gravel
}

struct ColorBoundary
{
    fileprivate static let d = 8
    
    fileprivate static func low(_ a: Int) -> UInt8 { return UInt8(Swift.min(a, 255)) }
    fileprivate static func high(_ a: Int) -> UInt8 { return UInt8(Swift.max(a, 0)) }

    init(mid: ImageHelpers.Color)
    {
        self.min = (red: ColorBoundary.high(Int(mid.red) - ColorBoundary.d),
                    green: ColorBoundary.high(Int(mid.green) - ColorBoundary.d),
                    blue: ColorBoundary.high(Int(mid.blue) - ColorBoundary.d),
                    alpha: 255)
        self.max = (red: ColorBoundary.low(Int(mid.red) + ColorBoundary.d),
                    green: ColorBoundary.low(Int(mid.green) + ColorBoundary.d),
                    blue: ColorBoundary.low(Int(mid.blue) + ColorBoundary.d),
                    alpha: 255)
    }
    
    init(min: ImageHelpers.Color, max: ImageHelpers.Color)
    {
        self.min = min
        self.max = max
    }
    
    let min: ImageHelpers.Color
    let max: ImageHelpers.Color
}

class TerrainHelpers
{
    static let waterBoundaries = ColorBoundary(mid: (red: 117, green: 207, blue: 240, alpha: 255))
    static let woodsBoundaries = ColorBoundary(mid: (red: 220, green: 225, blue: 199, alpha: 255))
    static let forestBoundaries = ColorBoundary(mid: (red: 212, green: 217, blue: 186, alpha: 255))
    static let grassBoundaries = ColorBoundary(mid: (red: 230, green: 228, blue: 224, alpha: 255))

    static let lawnBoundaries = ColorBoundary(mid: (red: 170, green: 224, blue: 143, alpha: 255))
    static let lawn2Boundaries = ColorBoundary(mid: (red: 182, green: 229, blue: 157, alpha: 255))

    static let streetBoundaries = ColorBoundary(mid: (red: 255, green: 255, blue: 255, alpha: 255))

    
    static func populationType(forColor color: ImageHelpers.Color) -> PopulationType
    {
        if match(color: color, red: 117, green: 207, blue: 240) {
            return .water
        }
        else if match(color: color, red: 255, green: 255, blue: 255) {
            return .street
        }
        else if match(color: color, red: 230, green: 228, blue: 224) {
            return .gras
        }
        else if match(color: color, red: 220, green: 225, blue: 199) {
            return .woods
        }
        else if match(color: color, red: 212, green: 217, blue: 186) {
            return .forest
        }
        else if match(color: color, red: 212, green: 117, blue: 183) || match(color: color, red: 229, green: 222, blue: 184) {
            return .buildings
        }
        else if match(color: color, red: 170, green: 224, blue: 143) || match(color: color, red: 182, green: 229, blue: 157) {
            return .lawn
        }
        else if match(color: color, minRed: 0, maxRed: 190, minGreen: 0, maxGreen: 190, minBlue: 200, maxBlue: 255) {
            return .creek
        }
        else if match(color: color, minRed: 200, maxRed: 255, minGreen: 170, maxGreen: 255, minBlue: 0, maxBlue: 170) {
            return .gravel
        }
        return .unknown
    }
    
    static func display(type: PopulationType) -> String
    {
        switch type {
        case .unknown: return "unknown"
        case .water: return "water"
        case .street: return "street"
        case .gras: return "gras"
        case .woods: return "woods"
        case .forest: return "forest"
        case .buildings: return "buildings"
        case .lawn: return "lawn"
        case .creek: return "creek"
        case .gravel: return "gravel"
        }
    }
    
    fileprivate static func match(color c: ImageHelpers.Color, red: UInt, green: UInt8, blue: UInt8) -> Bool
    {
        let mr = Int(red) >= (Int(c.red) - ColorBoundary.d) && Int(red) <= (Int(c.red) + ColorBoundary.d)
        let mg = Int(green) >= (Int(c.green) - ColorBoundary.d) && Int(green) <= (Int(c.green) + ColorBoundary.d)
        let mb = Int(blue) >= (Int(c.blue) - ColorBoundary.d) && Int(blue) <= (Int(c.blue) + ColorBoundary.d)
        return mr && mg && mb
    }
    
    fileprivate static func match(color c: ImageHelpers.Color, minRed: UInt, maxRed: UInt, minGreen: UInt8, maxGreen: UInt8, minBlue: UInt8, maxBlue: UInt8) -> Bool
    {
        let mr = c.red >= minRed && c.red <= maxRed
        let mg = c.green >= minGreen && c.green <= maxGreen
        let mb = c.blue >= minBlue && c.blue <= maxBlue
        return mr && mg && mb
    }
}
