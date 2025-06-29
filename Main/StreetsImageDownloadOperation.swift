//
//  StreetsImageDownloadOperation.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 07.09.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import Foundation

class StreetsImageDownloadOperation: BaseOperation
{
    private let url: URL
    private let tile: Tile
    
    // ------------------------------------------------------------------------------------------------------
    // MARK: - Initialization -
    // ------------------------------------------------------------------------------------------------------
    
    required init(withTile tile: Tile)
    {
        self.tile = tile
        let urlStr = Globals.Mapbox.streetsUrlString(forTile: tile)
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
                Log.downloader("streets image download failed for \(self.url.absoluteString)")
                self.finish()
            }
        }) { (rid, data) in
            if rid == requestId {
                do {
                    let tmpFileName = try PathHelpers.streetsImagesPath(forTile: self.tile)
                    try data.write(to: tmpFileName)
                    Log.downloader("streets image downloaded and saved as \(Globals.FSNames.streetsFolder)/\(self.tile.filename())")
                }
                catch {
                    Log.error("Could not safe streets image file")
                }
                self.finish()
            }
        }
    }
    
    // ------------------------------------------------------------------------------------------------------
    // MARK: - End -
    // ------------------------------------------------------------------------------------------------------
}
