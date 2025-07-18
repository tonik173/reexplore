//
//  Mercator.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 01.07.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import Foundation
import Darwin

typealias Longitude = Double
typealias Latitude = Double

struct GeoLocation : CustomStringConvertible, Equatable
{
    static func == (lhs: GeoLocation, rhs: GeoLocation) -> Bool {
        return lhs.lat == rhs.lat && lhs.lon == rhs.lon
    }
    
    let lat: Latitude
    let lon: Longitude
    
    init(lat: Latitude, lon: Longitude)
    {
        self.lat = lat
        self.lon = lon
    }
    
    var description: String { return "\(lat.rounded(toPlaces: 6)), \(lon.rounded(toPlaces: 6))"}
}

struct Tile : CustomStringConvertible, Equatable, Hashable
{
    static func == (lhs: Tile, rhs: Tile) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y && lhs.zoom == rhs.zoom
    }

    var description: String { return "z\(zoom)x\(x)y\(y)"}

    let x: Int
    let y: Int
    let zoom: Int
    let xf: Double
    let yf: Double
    
    init(x: Int, y: Int, zoom: Int)
    {
        self.x = x
        self.y = y
        self.zoom = zoom
        self.xf = 0.0
        self.yf = 0.0
    }

    init(x: Int, y: Int, zoom: Int, xf: Double, yf: Double)
    {
        self.x = x
        self.y = y
        self.zoom = zoom
        self.xf = xf
        self.yf = yf
    }
    
    init(longitude: Longitude, latitude: Latitude, zoom: Int)
    {
        let (x, y) = Self.coordinatesFrom(longitude: longitude, latitude: latitude)
        let exp2zoom = exp2(Double(zoom))
        
        var xTile: Int
        var yTile: Int
        
        if x <= 0 {
            xTile = 0
        } else if x >= 1 {
            xTile = Int(exp2zoom - 1)
        } else {
            xTile = Int((x + epsilon) * exp2zoom)
        }
        
        if y <= 0 {
            yTile = 0
        } else if y >= 1 {
            yTile = Int(exp2zoom - 1)
        } else {
            yTile = Int((y + epsilon) * exp2zoom)
        }
        
        self.x = xTile
        self.y = yTile
        self.zoom = zoom
        self.xf = 0.0
        self.yf = 0.0
    }

    func filename() -> String
    {
        return "z\(zoom)x\(x)y\(y).png"
    }
    
    fileprivate static func coordinatesFrom(longitude: Double, latitude: Double) -> (x: Double, y: Double)
    {
        let x = (longitude / 360) + 0.5
        let sinedLatitude = sin(latitude / 360 * 2 * .pi)
        let y = 0.5 - (0.25 * log((1 + sinedLatitude) / (1 - sinedLatitude)) / .pi)
        return (x: x, y: y)
    }
}

struct BoundingBox
{
    let west: Longitude
    let south: Latitude
    let east: Longitude
    let north: Latitude
}

class Mercator
{
    fileprivate let llEpsilon = 1e-11
    fileprivate let maxZoom = 28

    fileprivate struct Cell
    {
        let xMin: Int
        let yMin: Int
        let xMax: Int
        let yMax: Int
    }
    
    fileprivate static func deg2rad(_ number: Double) -> Double { return number * .pi / 180 }
    fileprivate static func rad2deg(_ number: Double) -> Double { return number / .pi * 180 }
    fileprivate static func rshift(value: Int, n: Int) -> Int { return (value % 0x100000000) >> n }
    
    fileprivate func calculateZoom(for cell: Cell) -> Int
    {
        for z in 0...maxZoom {
            let mask = 1 << (32 - (z + 1))
            if (cell.xMin & mask != cell.xMax & mask) || (cell.yMin & mask != cell.yMax & mask) {
                return z
            }
        }
        return maxZoom
    }
    
    func boundingTile(with boundingBox: BoundingBox) -> Tile
    {
        let west = boundingBox.west
        var south = boundingBox.south
        var east = boundingBox.east
        let north = boundingBox.north
        
        east = east - llEpsilon
        south = south + llEpsilon
        
        let maxTile = Tile(longitude: east, latitude: south, zoom: 32)
        let minTile = Tile(longitude: west, latitude: north, zoom: 32)
        
        let cell = Cell(xMin: minTile.x, yMin: minTile.y, xMax: maxTile.x, yMax: maxTile.y)
        
        let z = calculateZoom(for: cell)
        let x = Self.rshift(value: cell.xMin, n: (32 - z))
        let y = Self.rshift(value: cell.yMin, n: (32 - z))
        
        return Tile(x: x, y: y, zoom: z)
    }
    
    func tile(longitude: Longitude, latitude: Latitude, zoom: Int) -> Tile
    {
        // https://en.wikipedia.org/wiki/Web_Mercator_projection
        let lon = Self.deg2rad(longitude)
        let lat = Self.deg2rad(latitude)
        let zoomlevel:Double = Double(zoom)
        let c = 256.0/(2 * Double.pi) * pow(2.0, zoomlevel)
        let e = Darwin.M_E

        let x = c * (lon + .pi)/256.0
        
        let phi = tan(.pi/4 + lat/2)
        let lnPhi = phi == 0 ? 0 : log(phi)/log(e)
        let y = c * (Double.pi - lnPhi)/256.0

        return Tile(x: Int(floor(x)), y: Int(floor(y)), zoom: zoom, xf: x, yf: y)
    }
    
    func geolocation(forTilex x: Double, tileY y: Double, zoom: Int) -> GeoLocation
    {
        let c = 256.0/(2 * Double.pi) * pow(2.0, Double(zoom))
        let lon = 256.0*x/c - .pi
        
        let e = Darwin.M_E
        let a = Double.pi - 256.0*y/c
        let phi = atan(pow(e, a))
        let lat = 2*(phi - .pi/4.0)
        
        return GeoLocation (lat: Self.rad2deg(lat), lon: Self.rad2deg(lon))
    }

    // https://www.geodatasource.com/developers/swift
    static func distanceInMeter(location1: GeoLocation, location2: GeoLocation) -> Double
    {
        let theta = location1.lon - location2.lon
        var dist = sin(deg2rad(location1.lat)) * sin(deg2rad(location2.lat)) + cos(deg2rad(location1.lat)) * cos(deg2rad(location2.lat)) * cos(deg2rad(theta))
        dist = acos(dist)
        dist = rad2deg(dist)
        dist = dist * 60 * 1.853159616 * 1000.0
        return dist
    }

}
