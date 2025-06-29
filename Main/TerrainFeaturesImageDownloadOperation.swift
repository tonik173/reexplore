//
//  TerrainFeaturesImageDownloadOperation.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 03.09.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import Foundation

class TerrainFeaturesImageDownloadOperation: BaseOperation
{
    private let url: URL
    private let tile: Tile
    
    // ------------------------------------------------------------------------------------------------------
    // MARK: - Initialization -
    // ------------------------------------------------------------------------------------------------------
    
    required init(withTile tile: Tile)
    {
        self.tile = tile
        let urlStr = Globals.Mapbox.terrainFeaturesUrlString(forTile: tile)
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
                Log.downloader("terrain features image download failed for \(self.url.absoluteString)")
                self.finish()
            }
        }) { (rid, data) in
            if rid == requestId {
                do {
                    let tmpFileName = try PathHelpers.terrainFeaturesImagesPath(forTile: self.tile)
                    try data.write(to: tmpFileName)
                    Log.downloader("terrain features image downloaded and saved as \(Globals.FSNames.terrainFeaturesFolder)/\(self.tile.filename())")
                }
                catch {
                    Log.error("Could not safe terrain features image file")
                }
                self.finish()
            }
        }
    }
    
    // ------------------------------------------------------------------------------------------------------
    // MARK: - End -
    // ------------------------------------------------------------------------------------------------------
}
