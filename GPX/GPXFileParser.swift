//
//  GPXFileParser.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 08.09.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import Foundation
import CoreGPX

class GPXFileParser
{
    let url: URL?
    fileprivate let mercator = Mercator()
    fileprivate var prevGeo: GeoLocation!
    fileprivate var minGeo: GeoLocation!
    fileprivate var maxGeo: GeoLocation!
    fileprivate var track: Track!
    
    convenience init()
    {
        let url = Bundle.main.url(forResource: "Hometrails", withExtension: "gpx")
        self.init(withUrl: url!)
    }
    
    required init(withUrl url: URL) {
        self.url = url
    }
    
    func getTileCoords() -> Track?
    {
        self.prevGeo = GeoLocation(lat: 0.0, lon: 0.0)
        self.minGeo = GeoLocation(lat: 90.0, lon: 180.0)
        self.maxGeo = GeoLocation(lat: -90.0, lon: -180.0)
        self.track = Track()

        self.parseCoords { (lat, long) -> Bool in
            self.addPoint(lat: lat, lon: long)
            return false
        }
        
        if let url = self.url {
            self.track.name = GPXFileParser.trackName(forUrl: url)
        }
        
        self.track.minTile = mercator.tile(longitude: self.minGeo.lon, latitude: self.minGeo.lat, zoom: Globals.Mapbox.zoom)
        self.track.maxTile = mercator.tile(longitude: self.maxGeo.lon, latitude: self.maxGeo.lat, zoom: Globals.Mapbox.zoom)

        return self.track
    }
    
    fileprivate func addPoint(lat: Double, lon: Double)
    {
        let geo = GeoLocation(lat: lat, lon: lon)
        let distance = Mercator.distanceInMeter(location1: geo, location2: self.prevGeo)
        //print("\(geo) - \(String(describing: self.prevGeo)): \(distance)m")
        if distance > 1.0 {
            self.prevGeo = geo
            let tile = mercator.tile(longitude: geo.lon, latitude: geo.lat, zoom: Globals.Mapbox.zoom)
            self.track.addPoint(tile: tile)
            
            self.minGeo = GeoLocation(lat: min(lat, self.minGeo.lat), lon: min(lon, self.minGeo.lon))
            self.maxGeo = GeoLocation(lat: max(lat, self.maxGeo.lat), lon: max(lon, self.maxGeo.lon))
        }
    }

    func getFirstWaypoint() -> GeoLocation?
    {
        var geoLocation: GeoLocation? = .none
        self.parseCoords { (lat, lon) -> Bool in
            geoLocation = GeoLocation(lat: lat, lon: lon)
            return true
        }
        return geoLocation
    }
    
    static func trackName(forUrl url: URL) -> String?
    {
        if let gpx = GPXParser(withPath: url.path)?.parsedData() {
            
            for track in gpx.tracks {
                if let name = track.name {
                    return name
                }
            }
        }
        return .none
    }
    
    fileprivate typealias CoordinateHandler = (_ lat: Latitude,_ lon: Longitude) -> Bool
    fileprivate func parseCoords(_ handler: CoordinateHandler)
    {
        if let path = self.url?.path {
            if let gpx = GPXParser(withPath: path)?.parsedData() {
                for waypoint in gpx.waypoints {
                    if let lat = waypoint.latitude, let lon = waypoint.longitude {
                        let exit = handler(lat, lon)
                        if exit { return }
                    }
                }
                
                for track in gpx.tracks {
                    for trackSegment in track.segments {
                        for trackpoint in trackSegment.points {
                            if let lat = trackpoint.latitude, let lon = trackpoint.longitude {
                                let exit = handler(lat, lon)
                                if exit { return }
                            }
                        }
                    }
                }
            }
        }
    }
}
