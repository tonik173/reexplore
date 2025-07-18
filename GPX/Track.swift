//
//  Track.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 08.09.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import Foundation
import Metal
import CoreImage

class Track : CustomStringConvertible
{
    var name: String?
    var tiles = [String:TrackTile]()
    var minTile: Tile!
    var maxTile: Tile!
    fileprivate let tileLength = 256
    fileprivate var coords = [Tile]()
    
    func addPoint(tile: Tile)
    {
        self.coords.append(tile)
    }

    func trackTile(forTile tile: Tile) -> TrackTile?
    {
        let key = tile.description
        if let trackTile = self.tiles[key] {
            return trackTile
        }
        return .none
    }
    
    var description: String
    {
        var text = "track spans \(self.tiles.count) tiles"
        for trackTile in self.tiles {
            text = text + "\n\(trackTile)"
        }
        return text
    }
    
    func renderTrackTiles(device: MTLDevice)
    {
        self.renderCompleteTrack(device: device)
    }
    
    fileprivate func renderCompleteTrack(device: MTLDevice)
    {
        if self.coords.count > 0 {
            let dimension = self.calculateTrackDimension()
            let bufferSize = 4 * dimension.width * dimension.height
            let rawData = UnsafeMutablePointer<UInt8>.allocate(capacity:bufferSize)
            if let context = CGContext(data: rawData,
                                       width: dimension.width,
                                       height: dimension.height,
                                       bitsPerComponent: 8,
                                       bytesPerRow: 4 * dimension.width,
                                       space: CGColorSpaceCreateDeviceRGB(),
                                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
                
                let rect = CGRect(x: 0, y: 0, width: dimension.width, height: dimension.height)
                context.setLineWidth(5.0)
                context.setStrokeColor(Globals.Colors.red)
                context.setLineCap(.round)
                
                // background
                context.clear(rect)
                
                // draw route
                context.beginPath()
                
                let prevPt = self.pointFor(coord: self.coords[0])
                context.move(to: prevPt)
                for coord in self.coords {
                    let curPt = self.pointFor(coord: coord)
                    context.addLine(to: curPt)
                    
                    // creates a list of all requred track tiles
                    self.addTile(tile: coord)
                }
                context.drawPath(using: .stroke)
                
                // rendering
                if let cgImage = context.makeImage() {
                    context.draw(cgImage, in: rect)
                    
                    // save image to temp folder
                    // let path = PathHelpers.tracksImagesPath(forTile: Tile(x: 0, y: 0, zoom: 0)).path
                    // ImageHelpers.write(toFile: path, image: cgImage)
                    
                    for trackTile in self.tiles.values {
                        let x = abs(trackTile.tile.x - self.minTile.x)
                        let y = abs(trackTile.tile.y - self.minTile.y)
                        let rect = CGRect(x: x * tileLength, y: y * tileLength, width: tileLength, height: tileLength)
                        if let tileImage = cgImage.cropping(to: rect) {
                            trackTile.createTexture(forCgImage: tileImage, device: device)
                            Log.gpx("texture for track tile \(trackTile.tile) created")
                        }
                    }
                }
            }
            rawData.deallocate()
        }
    }
    
    fileprivate func pointFor(coord: Tile) -> CGPoint
    {
        let x = CGFloat(coord.xf - Double(self.minTile.x))
        let y = CGFloat(coord.yf - Double(self.maxTile.y))
        let scaled = CGPoint(x: x * CGFloat(tileLength), y: y * CGFloat(tileLength))
        return scaled
    }
    
    fileprivate func addTile(tile: Tile)
    {
        let key = tile.description
        if let _ = self.tiles[key] {
        }
        else {
            let trackTile = TrackTile(tile: tile)
            self.tiles[key] = trackTile
        }
    }
    
    fileprivate func calculateTrackDimension() -> (width: Int, height: Int)
    {
        let width = (abs(self.maxTile.x - self.minTile.x) + 1) * tileLength
        let height = (abs(self.maxTile.y - self.minTile.y) + 1) * tileLength
        return (width: width, height: height)
    }
}
