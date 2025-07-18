//
//  PathHelpers.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 01.07.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import Foundation

class PathHelpers
{
    public static func heightmapsPath(forTile tile: Tile) throws -> URL
    {
        var tmpFileName = try PathHelpers.createTemporaryDirectoy(withName: Globals.FSNames.heightmapsFolder)
        tmpFileName.appendPathComponent(tile.filename())
        return tmpFileName
    }
    
    public static func satelliteImagesPath(forTile tile: Tile) throws -> URL
    {
        var tmpFileName = try PathHelpers.createTemporaryDirectoy(withName: Globals.FSNames.satelliteImagesFolder)
        tmpFileName.appendPathComponent(tile.filename())
        return tmpFileName
    }
    
    public static func terrainFeaturesImagesPath(forTile tile: Tile) throws -> URL
    {
        var tmpFileName = try PathHelpers.createTemporaryDirectoy(withName: Globals.FSNames.terrainFeaturesFolder)
        tmpFileName.appendPathComponent(tile.filename())
        return tmpFileName
    }
    
    public static func streetsImagesPath(forTile tile: Tile) throws -> URL
    {
        var tmpFileName = try PathHelpers.createTemporaryDirectoy(withName: Globals.FSNames.streetsFolder)
        tmpFileName.appendPathComponent(tile.filename())
        return tmpFileName
    }
    
    public static func tracksImagesPath(forTile tile: Tile) -> URL
    {
        do {
            var tmpFileName = try PathHelpers.createTemporaryDirectoy(withName: Globals.FSNames.tracksFolder)
            tmpFileName.appendPathComponent(tile.filename())
            return tmpFileName
        }
        catch let error as NSError {
            fatalError(error.localizedDescription)
        }
    }
    
    public static func debugPath(forFilename name: String) -> URL
    {
        do {
            var tmpFileName = try PathHelpers.createTemporaryDirectoy(withName: Globals.FSNames.debugFolder)
            tmpFileName.appendPathComponent(name)
            return tmpFileName
        }
        catch let error as NSError {
            fatalError(error.localizedDescription)
        }
    }
    
    public static func createTemporaryDirectoy(withName name: String) throws -> URL
    {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        return url
    }
    
    public static func getDocumentsDirectory() -> URL
    {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }
}
