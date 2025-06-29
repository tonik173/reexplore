//
//  MiniGameViewBase.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 15.04.21.
//  Copyright © 2021 n3xd software studios ag. All rights reserved.
//
import MetalKit

class MiniGameViewBase: MTKView
{
    fileprivate let elevationLayer = CALayer()
    fileprivate let elevationGenerator = ElevationViewGenerator();
    fileprivate var prevLocationInfo: LocationInfo?
    fileprivate var totalDistance: Double = 0
    
    override init(frame frameRect: CGRect, device: MTLDevice?)
    {
        super.init(frame: frameRect, device: device)
        self.initializeElevationLayer(frame: frameRect)
    }
    
    required init(coder: NSCoder)
    {
        super .init(coder: coder)
        self.initializeElevationLayer(frame: self.bounds)
    }
    
    fileprivate func initializeElevationLayer(frame frameRect: CGRect)
    {
        #if os(iOS)
        self.layer.addSublayer(elevationLayer)
        #else
        self.layer?.addSublayer(elevationLayer)
        #endif
    }
    
    func setLocation(info: LocationInfo)
    {
        self.append(info: info, prevInfo: self.prevLocationInfo)

        if let _ = self.prevLocationInfo {
            self.updateElevation()
        }
        else {
            self.resizeElevation(frame: self.bounds)
        }
        
        self.prevLocationInfo = info
    }
    
    func reloadElevationView(locations: [LocationInfo])
    {
        self.reset()
        
        var prevLocationInfo: LocationInfo? = .none
        for info in locations {
            self.append(info: info, prevInfo: prevLocationInfo)
            prevLocationInfo = info
        }
        self.prevLocationInfo = prevLocationInfo
    }

    func resizeElevation(frame frameRect: CGRect)
    {
        let width = frameRect.width
        let height = frameRect.height/3
        
        #if os(iOS)
        let y: CGFloat = frameRect.height - height
        #else
        let y: CGFloat = 0
        #endif
        
        self.elevationLayer.frame = CGRect(x: 0, y: y, width: width, height: height)
        self.updateElevation()
    }
    
    func reset()
    {
        self.totalDistance = 0
        self.elevationLayer.contents = nil
        self.elevationGenerator.reset()
    }
    
    fileprivate func updateElevation()
    {
        let width = self.elevationLayer.frame.width
        let height = self.elevationLayer.frame.height
        self.elevationGenerator.image(for: CGSize(width: width, height: height)) { image in
            DispatchQueue.main.async {
                self.elevationLayer.contents = image
            }
        }
    }
    
    fileprivate func append(info: LocationInfo, prevInfo: LocationInfo?)
    {
        if let prevInfo = prevInfo {
            let distance = Mercator.distanceInMeter(location1: prevInfo.geoCord, location2: info.geoCord)
            if distance > 50 {
                self.totalDistance += distance
                self.elevationGenerator.append(altitude: info.metersAboveSeeLevel, distance: Float(self.totalDistance/1000))
            }
        }
        else {
            self.elevationGenerator.append(altitude: info.metersAboveSeeLevel, distance: 0)
        }
    }
}
