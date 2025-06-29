//
//  TrackRecordTile.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 19.03.21.
//  Copyright © 2021 n3xd software studios ag. All rights reserved.
//
import Foundation
import Metal
import MetalKit
import CoreImage

class TrackRecordTile: CustomStringConvertible, Equatable
{
    static func == (lhs: TrackRecordTile, rhs: TrackRecordTile) -> Bool {
        return lhs.tile == rhs.tile
    }
    
    var description: String { return "\(tile.description) has \(segments.count) segments"}
    let tile: Tile
    var texture: MTLTexture? = .none
    fileprivate var segments = [TrackSegment]()
    fileprivate var isUpdatingTexture = false

    init(withTile tile: Tile)
    {
        self.tile = tile
    }
    
    func addTrackPoint(position: float2, location: GeoLocation, inSegment segmentIndex: Int)
    {
        let sideLen = TerrainTile.sideLen * TerrainTile.scale
        let offset = sideLen * Float(UInt16.max)
        let halfSideLen = TerrainTile.halfSideLen * TerrainTile.scale
        
        let xt = halfSideLen + offset + position.x
        let x = xt.truncatingRemainder(dividingBy: sideLen)
        
        let yt = halfSideLen + offset + position.y
        let y = sideLen - yt.truncatingRemainder(dividingBy: sideLen)
        
        let pt = CGPoint(x: CGFloat(x), y: CGFloat(y))
        
        // appends pt and position to the proper segment
        if self.segments.count == 0 {
            // thats the very first segment
            self.appendTrackSegment(withFirstLocation: location, firstPoint: pt, index: segmentIndex)
        }
        else if let lastSegmentIndex = self.segments.last?.number {
            if lastSegmentIndex == segmentIndex {
                // we already have a segment for this index
                let index = self.segments.count - 1
                self.segments[index].points.append(pt)
            }
            else {
                // this segment does not exist yet
                self.appendTrackSegment(withFirstLocation: location, firstPoint: pt, index: segmentIndex)
            }
        }
        
        Log.gui("added pt \(pt.x)/\(pt.y) (position \(position.x)/\(position.y)) into segment \(segmentIndex) of tile \(tile)")

        // updates texture
        if !isUpdatingTexture {
            isUpdatingTexture = true
            DispatchQueue.global(qos: .userInteractive).async {
                self.drawTrack()
                self.isUpdatingTexture = false
            }
        }
    }
    
    fileprivate func appendTrackSegment(withFirstLocation location: GeoLocation, firstPoint pt: CGPoint, index: Int)
    {
        let segment = TrackSegment(number: index, firstLocation: location)
        segment.points.append(pt)
        self.segments.append(segment)
    }
    
    fileprivate func hasTrackPoints() -> Bool
    {
        for segment in self.segments {
            if segment.points.count > 0 {
                return true
            }
        }
        return false
    }
        
    fileprivate func drawTrack()
    {
        if self.hasTrackPoints() {
            let width = Int(TerrainTile.sideLen * TerrainTile.scale)
            let height = width
            let bufferSize = 4 * width * height
            let rawData = UnsafeMutablePointer<UInt8>.allocate(capacity:bufferSize)
            if let context = CGContext(data: rawData,
                                       width: width,
                                       height: height,
                                       bitsPerComponent: 8,
                                       bytesPerRow: 4 * width,
                                       space: CGColorSpaceCreateDeviceRGB(),
                                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
                
                let rect = CGRect(x: 0, y: 0, width: width, height: height)
                context.setLineWidth(2.0)
                context.setStrokeColor(Globals.Colors.purple)
                context.setLineCap(.round)
                
                // background
                context.clear(rect)
                
                // draw route
                for segment in segments {
                    for curPt in segment.points {
                        context.beginPath()
                        context.move(to: curPt)
                        context.addLine(to: curPt)
                        context.drawPath(using: .stroke)
                    }
                }
                
                // rendering
                if let cgImage = context.makeImage() {
                    context.draw(cgImage, in: rect)
                    
                    do {
                        let textureLoader = MTKTextureLoader(device: Renderer.device)
                        let options: [MTKTextureLoader.Option : Any] = [MTKTextureLoader.Option.SRGB: 0,
                                                                        MTKTextureLoader.Option.allocateMipmaps: 0,
                                                                        MTKTextureLoader.Option.textureUsage: MTLTextureUsage.shaderRead.rawValue,
                                                                        MTKTextureLoader.Option.origin: MTKTextureLoader.Origin.topLeft]
                        self.texture = try textureLoader.newTexture(cgImage: cgImage, options:options)
                    }
                    catch let error as NSError {
                        fatalError(error.localizedDescription)
                    }
                }
            }
            rawData.deallocate()
        }
    }
    
    func backToStartOfTrackSegment(index: Int) -> GeoLocation?
    {
        // get the first point of in the segment at index
        var firstLocation: GeoLocation? = .none
        let segmentIndex = self.segments.firstIndex { (segment) -> Bool in segment.number == index }
        if let segmentIndex = segmentIndex {
            firstLocation = self.segments[segmentIndex].firstLocation
        }
        
        // remove all trackpoints in the current and higher segments
        var newSegments = [TrackSegment]()
        for i in 0..<self.segments.count {
            let curSegment = self.segments[i]
            if self.segments[i].number == index {
                curSegment.clearToFirst()
                newSegments.append(curSegment)
            }
            else if self.segments[i].number < index {
                newSegments.append(curSegment)
            }
        }
        self.segments = newSegments
        
        DispatchQueue.global(qos: .userInteractive).async {
            self.drawTrack()
        }
        
        return firstLocation
    }
}

// ------------------------------------------------------------------------------------------------------
// MARK: - TrackSegment
// ------------------------------------------------------------------------------------------------------

fileprivate class TrackSegment
{
    var number: Int
    var points: [CGPoint]            // used for drawing
    var firstLocation: GeoLocation?  // used for back tracking

    init()
    {
        self.number = 1
        self.points = [CGPoint]()
        self.firstLocation = .none
    }
    
    init(number: Int, firstLocation: GeoLocation)
    {
        self.number = number
        self.points = [CGPoint]()
        self.firstLocation = firstLocation
    }
    
    fileprivate func clearToFirst()
    {
        let firstPoint = self.points.first
        self.points.removeAll()
        if let firstPoint = firstPoint {
            self.points.append(firstPoint)
        }
    }
}

