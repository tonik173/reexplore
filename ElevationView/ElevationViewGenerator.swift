//
//  ElevationViewGenerator.swift
//  Reexplore
//
//  Created by Flavian Kaufmann on 28.03.21.
//  Copyright © 2021 n3xd software studios ag. All rights reserved.
//

import Foundation
import CoreGraphics
import CoreText

class ElevationViewGenerator {
    
    // MARK: - Properties
    
    /// All recorded altitude points
    fileprivate var altitudePoints: [AltitudePoint] = []
    fileprivate var isDrawing = false
    fileprivate let textLabelAttrs: [NSAttributedString.Key: Any] = [
        .foregroundColor: CGColor(red: 1, green: 1, blue: 1, alpha: 1.0),
    ]
    
    // MARK: - Interface
    
    /// Appends an altitude point to the data set
    /// - Parameters:
    ///   - altitude: Altitude of current point
    ///   - distance: Distance since first altitude point
    func append(altitude: Float, distance: Float)
    {
        let altitudePoint = AltitudePoint(altitude: altitude, distance: distance)
        self.altitudePoints.append(altitudePoint)
        // Log.gpx("masl: \(altitude), distance: \(distance)")
    }
    
    /// Removes all altitude points
    func reset()
    {
        self.altitudePoints.removeAll()
    }
    
    func image(for size: CGSize, handler: @escaping (CGImage?) -> Void)
    {
        if self.isDrawing { return }
        
        let altitudePoints = self.altitudePoints // Copies Altitude Points for thread safety
        guard altitudePoints.count > 1 else { return } // Guard that there are at least two points
        let totalDistance = Self.totalDistance(of: altitudePoints)
        let maxAltitude = Self.maxAltitude(of: altitudePoints)
        let minAltitude = Self.minAltitude(of: altitudePoints)
        
        // Do image generation in background thread
        DispatchQueue.global(qos: .background).async {
            self.isDrawing = true
            
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue
            let bounds = CGRect(origin: .zero, size: size)
            
            // Creates Core Graphics Context
            guard let context = CGContext(data: nil,
                                          width: Int(bounds.width),
                                          height: Int(bounds.height),
                                          bitsPerComponent: 8,
                                          bytesPerRow: 0, // Auto calculate bytes per row
                                          space: colorSpace,
                                          bitmapInfo: bitmapInfo) else { return }
            
            // Fill background with desired color
            //context.setFillColor(CGColor(colorSpace: colorSpace, components: [1, 1, 1, 1])!)
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.0))
            context.fill(bounds)
            
            // Draw elevation profile
            let elevationProfilePath = CGMutablePath()

            let coordinates = altitudePoints.map { altitudePoint in
                Self.coordinates(for: altitudePoint,
                                 totalDistance: totalDistance,
                                 maxAltitude: maxAltitude,
                                 minAltitude: minAltitude,
                                 in: bounds)
            } // Calculate coordinates in context space
            
            elevationProfilePath.move(to: coordinates[0]) // Move path cursor to first point
            
            for coordinate in coordinates.suffix(from: 1) { // Draw lines to subsequent points
                elevationProfilePath.addLine(to: coordinate)
            }
            
            elevationProfilePath.addLine(to: CGPoint(x: bounds.width, y: 0))  // Complete path
            elevationProfilePath.addLine(to: bounds.origin)
            
            context.addPath(elevationProfilePath)
            context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.5))
            context.fillPath()
            
            // Draw labels
    
            let minAltitudeText = NSAttributedString(string: "\(Int(minAltitude)) m", attributes: self.textLabelAttrs)
            Self.draw(text: minAltitudeText, bottomLeftPos: CGPoint(x: 10, y: 10), alignCenter: false, on: context)
            
            let maxAltitudeText = NSAttributedString(string: "\(Int(maxAltitude)) m", attributes: self.textLabelAttrs)
            Self.draw(text: maxAltitudeText, bottomLeftPos: CGPoint(x: 10, y: bounds.maxY - 25), alignCenter: false, on: context)
            
            let km = String(format: "%0.2f", totalDistance)
            let distanceText = NSAttributedString(string: "\(km) km", attributes: self.textLabelAttrs)
            Self.draw(text: distanceText, bottomLeftPos: CGPoint(x: bounds.midX, y: 10), alignCenter: true, on: context)
            
            // Generate CGImage
            let image = context.makeImage()
            handler(image)
            
            self.isDrawing = false
        }
    }
    
    // MARK: - Helpers
    
    fileprivate static func draw(text: NSAttributedString, bottomLeftPos: CGPoint, alignCenter: Bool, on context: CGContext)
    {
        let framesetter = CTFramesetterCreateWithAttributedString(text as CFAttributedString)
        let suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRange(location: 0, length: text.length), nil, CGSize(width: .max, height: .max), nil)
        
        let labelBkgndHorizontalAddition: CGFloat = 2
        let labelBkgndVerticalAddition: CGFloat = -1
        let suggestedSizeWithBoundary = CGSize(width: suggestedSize.width + 2 * labelBkgndHorizontalAddition, height: suggestedSize.height + 2 * labelBkgndVerticalAddition)
        
        let position = alignCenter ? CGPoint(x: bottomLeftPos.x - suggestedSizeWithBoundary.width/2, y: bottomLeftPos.y) : bottomLeftPos
        
        // Add label background
        context.saveGState()
        let path = CGMutablePath()
        path.addRoundedRect(in: CGRect(origin: position, size: suggestedSizeWithBoundary), cornerWidth: 3, cornerHeight: 2)
        context.addPath(path)
        context.setFillColor(CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0))
        context.fillPath()
        context.restoreGState()

        let textPath = CGMutablePath()
        let newPosition = CGPoint(x: position.x + labelBkgndHorizontalAddition, y: position.y + labelBkgndVerticalAddition)
        textPath.addRect(CGRect(origin: newPosition, size: suggestedSize))
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: text.length), textPath, nil)
        CTFrameDraw(frame, context)
    }
    
    fileprivate static func coordinates(for point: AltitudePoint,
                                    totalDistance: Float,
                                    maxAltitude: Float,
                                    minAltitude: Float,
                                    in rect: CGRect) -> CGPoint {
        let x = CGFloat(point.distance / totalDistance) * rect.width
        let heightDifference = maxAltitude - minAltitude
        let y = CGFloat((point.altitude - minAltitude) / heightDifference) * rect.height
        return CGPoint(x: x, y: y)
    }
    
    fileprivate static func totalDistance(of altitudePoints: [AltitudePoint]) -> Float {
        return altitudePoints.last?.distance ?? 0
    }
    
    fileprivate static func maxAltitude(of altitudePoints: [AltitudePoint]) -> Float {
        return (altitudePoints.max { $0.altitude < $1.altitude })?.altitude ?? 0
    }
    
    fileprivate static func minAltitude(of altitudePoints: [AltitudePoint]) -> Float {
        return (altitudePoints.min { $0.altitude < $1.altitude })?.altitude ?? 0
    }
    
    fileprivate struct AltitudePoint {
        let altitude: Float
        let distance: Float
    }
}
