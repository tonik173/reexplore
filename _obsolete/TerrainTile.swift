//
//  TerrainTile.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 06.11.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import Foundation

class TerrainTile: CustomStringConvertible, Equatable
{
    static func == (lhs: TerrainTile, rhs: TerrainTile) -> Bool {
        let isSameTile = lhs.tile == rhs.tile
        return isSameTile
        /*
        var areSameGrounds = lhs.groundTiles.count == rhs.groundTiles.count
        if areSameGrounds {
            areSameGrounds = lhs.groundTiles.allSatisfy { (lhsGround) -> Bool in
                return rhs.groundTiles.first { (rhsGround) -> Bool in
                    return lhsGround == rhsGround
                } == .none ? false : true
            }
        }
        return isSameTile && areSameGrounds*/
    }

    fileprivate let tile: Tile
    fileprivate var groundTiles: [Ground]
    
    init(withTile tile: Tile, ground: Ground)
    {
        self.tile = tile
        self.groundTiles = [ground]
    }
    
    var description: String {
        
        var str: String? = .none
        for groundTile in self.groundTiles {
            let gtstr = groundTile.description
            if str == .none {
                str = gtstr
            }
            else {
                str = "\(String(describing: str))\n\(gtstr)"
            }
        }
        return str == .none ? "" : str!
    }
    
    func addGround(_ groundTile: Ground)
    {
        self.groundTiles.append(groundTile)
    }
}

