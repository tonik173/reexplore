//
//  MapboxItemsDownloader.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 02.07.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import Foundation

class MapboxItemsDownloader: NSObject
{
    typealias SuccessHandler = () -> Void
    
    struct Consts {
        static let queueOperationsChanged = UnsafeMutableRawPointer(bitPattern: 1703)
    }
    
    struct Notifications {
        static let mapboxItemsDownloadDone = NSNotification.Name(rawValue: "mapboxItemsDownloadDone")
    }
    
    static let sharedInstance: MapboxItemsDownloader = {
        let sharedInstance = MapboxItemsDownloader()
        return sharedInstance
    }()
    
    private let itemsDownloadQueue: OperationQueue
    private var allDownloadsDone = false
    
    // ------------------------------------------------------------------------------------------------------
    // MARK: - Initialization
    // ------------------------------------------------------------------------------------------------------
    
    class func shared() -> MapboxItemsDownloader { return sharedInstance }
    
    private override init()
    {
        self.itemsDownloadQueue = OperationQueue()
        self.itemsDownloadQueue.name = "item download queue"
        self.itemsDownloadQueue.qualityOfService = .userInteractive
        
        super.init()
        
        self.itemsDownloadQueue.addObserver(self, forKeyPath: "operations", options: [.new], context: Consts.queueOperationsChanged)
    }
    
    deinit {}
    
    // once the download queue is empty, the gui gets updated
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?)
    {
        if context == Consts.queueOperationsChanged {
            if self.itemsDownloadQueue.operations.count == 0 {
                DispatchQueue.main.async {
                    self.allDownloadsDone = true
                    NotificationCenter.default.post(name: Notifications.mapboxItemsDownloadDone, object: nil)
                }
            }
        }
        else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    // ------------------------------------------------------------------------------------------------------
    // MARK: - Services
    // ------------------------------------------------------------------------------------------------------
    
    func downloadItems(forLatitude latitude: Double, longitude: Double)
    {
        let mercator = Mercator()
        let tile = mercator.tile(longitude: longitude, latitude: latitude, zoom: Globals.Mapbox.zoom)
        
        self.allDownloadsDone = false
        DispatchQueue.global(qos: .userInitiated).async {
            self.downloadItems(forTile: tile)
        }
    }
    
    func downloadItems(forTile tile: Tile)
    {
        let numOfHorizontalTilesFromOrigin = 0
        let numOfVerticalTilesFromOrigin = 0
        let horizontalStartTile = tile.x
        let verticalStartTile = tile.y

        for x in (horizontalStartTile-numOfHorizontalTilesFromOrigin)...(horizontalStartTile + numOfHorizontalTilesFromOrigin) {
            for y in (verticalStartTile-numOfVerticalTilesFromOrigin)...(verticalStartTile + numOfVerticalTilesFromOrigin) {
                let tile = Tile(x: x, y: y, zoom: tile.zoom)
                self.downloadHeightmapTiles(forTile: tile)
                self.downloadSatelliteImages(forTile: tile)
                self.downloadStreetsImages(forTile: tile)
            }
        }
    }
    
    // ------------------------------------------------------------------------------------------------------
    // MARK: - Helpers
    // ------------------------------------------------------------------------------------------------------
    
    fileprivate func downloadHeightmapTiles(forTile tile: Tile)
    {
        do {
            let cachedUrl = try PathHelpers.heightmapsPath(forTile: tile)
            if !FileManager.default.fileExists(atPath: cachedUrl.relativePath) {
                let downloadOperation = HeightmapDownloadOperation(withTile: tile)
                self.itemsDownloadQueue.addOperation(downloadOperation)
            }
        }
        catch {
            Log.error("cannot access heightmap file")
        }
    }

    fileprivate func downloadSatelliteImages(forTile tile: Tile)
    {
        do {
            let cachedUrl = try PathHelpers.satelliteImagesPath(forTile: tile)
            if !FileManager.default.fileExists(atPath: cachedUrl.relativePath) {
                let downloadOperation = SatelliteImageDownloadOperation(withTile: tile)
                self.itemsDownloadQueue.addOperation(downloadOperation)
            }
        }
        catch {
            Log.error("cannot access satellite image file")
        }
    }
    
    fileprivate func downloadTerrainFeaturesImages(forTile tile: Tile)
    {
        do {
            let cachedUrl = try PathHelpers.terrainFeaturesImagesPath(forTile: tile)
            if !FileManager.default.fileExists(atPath: cachedUrl.relativePath) {
                let downloadOperation = TerrainFeaturesImageDownloadOperation(withTile: tile)
                self.itemsDownloadQueue.addOperation(downloadOperation)
            }
        }
        catch {
            Log.error("cannot access terrain features image file")
        }
    }
    
    fileprivate func downloadStreetsImages(forTile tile: Tile)
    {
        do {
            let cachedUrl = try PathHelpers.streetsImagesPath(forTile: tile)
            if !FileManager.default.fileExists(atPath: cachedUrl.relativePath) {
                let downloadOperation = StreetsImageDownloadOperation(withTile: tile)
                self.itemsDownloadQueue.addOperation(downloadOperation)
            }
        }
        catch {
            Log.error("cannot access streets image file")
        }
    }
    
    // ------------------------------------------------------------------------------------------------------
    // MARK: - End
    // ------------------------------------------------------------------------------------------------------
}
