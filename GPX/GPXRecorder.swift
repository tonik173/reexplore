//
//  GPXRecorder.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 26.02.21.
//  Copyright © 2021 n3xd software studios ag. All rights reserved.
//
import Foundation
import CoreGPX

class GPXRecorder
{
    fileprivate let root = GPXRoot(creator: "Created with ReExplore")
    fileprivate let track = GPXTrack()
    fileprivate var segments = [GPXTrackSegment]()
    
    func append(location: GeoLocation, meterAboveSeeLevel masl: Float)
    {
        if let curSegment = self.segments.last {
            let trackpoint = GPXTrackPoint(latitude: location.lat, longitude: location.lon)
            trackpoint.elevation = Double(masl)
            curSegment.add(trackpoint: trackpoint)
        }
    }
    
    func numberOfSegments() -> Int
    {
        return self.segments.count
    }
    
    func incrementSegment()
    {
        let segment = GPXTrackSegment()
        self.segments.append(segment)
        Log.gpx("number of segments after inc: \(self.segments.count)")
    }
    
    func decrementSegment()
    {
        if numberOfSegments() > 0 {
            self.segments.removeLast()
            Log.gpx("number of segments after dec: \(self.segments.count)")
        }
    }
    
    func clearSegment()
    {
        self.decrementSegment()
        self.incrementSegment()
        Log.gpx("number of segments after clear: \(self.segments.count)")
    }
    
    func getGPX() -> String
    {
        for segment in self.segments {
            self.track.add(trackSegment: segment)
        }
        self.root.add(track: track)
        
        let xml = root.gpx()
        return xml
    }
    
    func getRoute() -> [LocationInfo]
    {
        var locations = [LocationInfo]()
        for segment in self.segments {
            for trackPoint in segment.points {
                if let lat = trackPoint.latitude,
                   let lon = trackPoint.longitude,
                   let elevation = trackPoint.elevation {
                    let location = GeoLocation(lat: lat, lon: lon)
                    let info = LocationInfo(name: "", position: float3(repeating: 0), geoCord: location, metersAboveSeeLevel: Float(elevation), info: .none)
                    locations.append(info)
                }
            }
        }
        return locations
    }
}

