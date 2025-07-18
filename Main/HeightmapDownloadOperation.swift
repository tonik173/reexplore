//
//  HeightmapDownloadOperation.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 01.07.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import Foundation

class HeightmapDownloadOperation: BaseOperation
{
    private let url: URL
    private let tile: Tile
    
    // ------------------------------------------------------------------------------------------------------
    // MARK: - Initialization -
    // ------------------------------------------------------------------------------------------------------
    
    required init(withTile tile: Tile)
    {
        self.tile = tile
        let urlStr = Globals.Mapbox.heightmapUrlString(forTile: tile)
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
                Log.downloader("heightmap tile download failed for \(self.url.absoluteString)")
                self.finish()
            }
        }) { (rid, data) in
            if rid == requestId {
                do {
                    let tmpFileName = try PathHelpers.heightmapsPath(forTile: self.tile)
                    try data.write(to: tmpFileName)
                    Log.downloader("heightmap tile downloaded and saved as \(Globals.FSNames.heightmapsFolder)/\(self.tile.filename())")
                }
                catch {
                    Log.error("Could not safe heightmap file")
                }
                self.finish()
            }
        }
    }
    
    // ------------------------------------------------------------------------------------------------------
    // MARK: - End -
    // ------------------------------------------------------------------------------------------------------
}
