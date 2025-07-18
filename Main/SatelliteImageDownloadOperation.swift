//
//  SatelliteImageDownloadOperation.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 02.07.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import Foundation

class SatelliteImageDownloadOperation: BaseOperation
{
    private let url: URL
    private let tile: Tile
    
    // ------------------------------------------------------------------------------------------------------
    // MARK: - Initialization -
    // ------------------------------------------------------------------------------------------------------
    
    required init(withTile tile: Tile)
    {
        self.tile = tile
        let urlStr = Globals.Mapbox.satelliteUrlString(forTile: tile)
        self.url = URL(string: urlStr)!
        super.init()
    }
    
    // ------------------------------------------------------------------------------------------------------
    // MARK: - Overrides -
    // ------------------------------------------------------------------------------------------------------
    
    override func execute()
    {
        let client = DownloadClient()
        let requestId: UInt = self.nextRequestId()
        client.execute(with: self.url, withId: requestId, failureHandler: { (rid, reason, error)  in
            if rid == requestId {
                Log.downloader("satellite image download failed for \(self.url.absoluteString)")
                self.finish()
            }
        }) { (rid, data) in
            if rid == requestId {
                do {
                    let tmpFileName = try PathHelpers.satelliteImagesPath(forTile: self.tile)
                    try data.write(to: tmpFileName)
                    Log.downloader("satellite image downloaded and saved as \(Globals.FSNames.satelliteImagesFolder)/\(self.tile.filename())")
                }
                catch {
                    Log.error("Could not safe satellite image file")
                }
                self.finish()
            }
        }
    }
    
    // ------------------------------------------------------------------------------------------------------
    // MARK: - End -
    // ------------------------------------------------------------------------------------------------------
}
