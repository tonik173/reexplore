//
//  Geocoder.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 24.01.21.
//  Copyright © 2021 n3xd software studios ag. All rights reserved.
//
import Foundation
import CoreLocation

struct LocationInfo: CustomStringConvertible
{
    let name: String
    let position: float3
    let geoCord: GeoLocation
    let metersAboveSeeLevel: Float
    let info: String?
    
    var description: String {
        if let info = self.info {
            return "\(self.name) at \(geoCord.description), \(info)"
        }
        return "\(self.name) at \(geoCord.description)"
    }
}

class Geocoder
{
    fileprivate let geocoder = CLGeocoder()
    fileprivate let mercator = Mercator()
    fileprivate let locations: SynchronizedArray<LocationInfo>
    fileprivate var index = 0
    fileprivate static let maxLocations = 2000
    fileprivate var lookingUp = false
    
    init()
    {
        self.locations = SynchronizedArray<LocationInfo>()
        let info = LocationInfo(name: "", position: float3(repeating: 0), geoCord: GeoLocation(lat: 0, lon: 0), metersAboveSeeLevel: 0, info: .none)
        for _ in 0..<Geocoder.maxLocations {
            self.locations.append(info)
        }
    }

    func lookupLocation(position: float3, meterAboveSeeLevel masl: Float, inTile tile: Tile) -> LocationInfo
    {
        // returns the cache info if there's any
        if let info = self.locationInfo(forPosition: position) {
            return info
        }
        
        // calculate lat/lon for position and start retrieving place
        let coord = self.mercator.geolocation(forTilex: tile.xf, tileY: tile.yf, zoom: tile.zoom)
        self.lookupPlace(forCoord: coord, atPosition: position, meterAboveSeeLevel: masl)
        
        // place search runs in background. We return just the coord at this time.
        return LocationInfo(name: "", position: position, geoCord: coord, metersAboveSeeLevel: masl, info: .none)
    }
    
    fileprivate func key(forPosition position: float3) -> String
    {
        let c: Float = 15
        let x = round(position.x/c)*c
        let y = round(position.y/c)*c
        let z = round(position.z/c)*c
        return "\(x)/\(y)/\(z)"
    }
    
    fileprivate func locationInfo(forPosition position: float3) -> LocationInfo?
    {
        var i = index - 1
        while i >= 0 {
            if let info = self.locations[i] {
                let key1 = self.key(forPosition: position)
                let key2 = self.key(forPosition: info.position)
                if key1 == key2 {
                    return info
                }
            }
            i -= 1
        }
        return .none
    }
    
    fileprivate func lookupPlace(forCoord coord: GeoLocation, atPosition position: float3, meterAboveSeeLevel masl: Float)
    {
        guard !lookingUp else { return }
        
        lookingUp = true
        DispatchQueue.global(qos: .userInteractive).async {
            let cllocation = CLLocation(latitude: coord.lat, longitude: coord.lon)
            self.lookupLocation(cllocation) { (placemark) in
                if let placemark = placemark {
                    if let street = placemark.name,
                       let city = placemark.locality {
                        let info = LocationInfo(name: self.key(forPosition: position),
                                                position: position,
                                                geoCord: coord,
                                                metersAboveSeeLevel: masl,
                                                info: "\(street), \(city)")
                        self.locations[self.index] = info
                        self.index = (self.index + 1) % Geocoder.maxLocations
                        Log.gpx("New place: \(info.description)")
                        DispatchQueue.main.async {
                            self.lookingUp = false
                        }
                    }
                }
            }
        }
    }
    
    fileprivate func lookupLocation(_ location: CLLocation, completionHandler: @escaping (CLPlacemark?) -> Void)
    {
        geocoder.reverseGeocodeLocation(location, completionHandler: { (placemarks, error) in
            if error == nil {
                let firstLocation = placemarks?[0]
                completionHandler(firstLocation)
            }
            else {
                completionHandler(nil)
            }
        })
    }
}
