//
//  TrackRecorder.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 12.03.21.
//  Copyright © 2021 n3xd software studios ag. All rights reserved.
//
import Foundation
import MetalKit

class TrackRecorder
{
    fileprivate var gpx: GPXRecorder?
    fileprivate var recordedTrackTiles = [TrackRecordTile]()
    fileprivate var curTrackTile: TrackRecordTile? = .none
    fileprivate var curSegmentIndex: Int = 0
    
    func start(name: String)
    {
        let track = Track()
        track.name = "Recorded track"
        self.gpx = GPXRecorder()
        self.curSegmentIndex = 0
    }
    
    func append(location: GeoLocation, meterAboveSeeLevel masl: Float, forTile tile: Tile, atPosition position: float2)
    {
        // gpx file
        guard let gpx = self.gpx else { return }
        gpx.append(location: location, meterAboveSeeLevel:masl)

        // instant drawing on current tile
        if let trackTile = self.currentTrackTile(forTile: tile) {
            trackTile.addTrackPoint(position: position, location: location, inSegment: self.curSegmentIndex)
        }
    }
    
    func stop(recordedTrackHandler: @escaping (String) -> Void)
    {
        if let gpx = self.gpx {
            let xml = gpx.getGPX()
            recordedTrackHandler(xml)
        }
        self.recordedTrackTiles.removeAll()
        self.gpx = .none
    }
    
    func trackTexture(forTile tile: Tile) -> MTLTexture?
    {
        let trackTile = self.recordedTrackTiles.first { (trackTile) -> Bool in trackTile.tile == tile }
        if let trackTile = trackTile {
            return trackTile.texture
        }
        return .none
    }
    
    func incrementSegment()
    {
        self.curSegmentIndex += 1
        if let gpx = self.gpx {
            gpx.incrementSegment()
        }
    }
    
    func decrementSegment(isPartial: Bool) -> GeoLocation?
    {
        guard let gpx = self.gpx else { return .none }

        if isPartial {
            gpx.clearSegment()
        }
        else {
            self.curSegmentIndex -= 1
            gpx.decrementSegment()
            gpx.clearSegment()
        }
        
        var start: GeoLocation? = .none
        for trackTile in self.recordedTrackTiles {
            if let lastPos = trackTile.backToStartOfTrackSegment(index: self.curSegmentIndex) {
                start = lastPos
            }
        }
        
        return start
    }
    
    func getRoute() -> [LocationInfo]
    {
        var locations = [LocationInfo]()
        if let gpx = self.gpx {
            locations = gpx.getRoute()
        }
        return locations
    }
    
    // ------------------------------------------------------------------------------------------------------
    // MARK: - Private
    // ------------------------------------------------------------------------------------------------------
    fileprivate var prevTile: Tile? = .none
    
    fileprivate func recordedTrackTile(forTile tile: Tile) -> TrackRecordTile?
    {
        if prevTile == tile {
            if let curTrackTile = self.curTrackTile {
                // its cached
                return curTrackTile
            }
        }
        
        self.prevTile = tile
        
        self.curTrackTile = self.recordedTrackTiles.first { (trackTile) -> Bool in trackTile.tile == tile }
        if let curTrackTile = self.curTrackTile {
            // its already created
            return curTrackTile
        }

        return .none
    }
    
    fileprivate func currentTrackTile(forTile tile: Tile) -> TrackRecordTile?
    {
        if let curTrackTile = self.recordedTrackTile(forTile: tile) {
            return curTrackTile
        }

        // its missing. create it
        let trackTile = TrackRecordTile(withTile: tile)
        self.recordedTrackTiles.append(trackTile)
        self.curTrackTile = trackTile
        return trackTile
    }
}
