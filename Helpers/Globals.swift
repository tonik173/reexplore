//
//  Globals.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 01.07.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import Foundation
import CoreGraphics
import MetalKit

typealias SuccessHandler = () -> Void
typealias DoneHandler = (_ success: Bool) -> Void

enum TextureType
{
    case gpuHeightmap
    case image
}

enum TerrainType : Int
{
    case map = 0
    case enhanced
    case satellite
    case mixed
    case custom
}

enum GearType : Int
{
    case runner = 0
    case biker
}

enum ControlSide : Int
{
    case left = 0
    case right
}

enum CameraType
{
    case firstPerson
    case orthograhic
}

struct GameConfig
{
    enum ChangedProperty
    {
        case debugInfo
        case debugWirefame
        case terrainStyle
        case cameraType
        case gearType
        case aboveGround
        case location
        case gpxFileUrl
        case trackVisibility
        case customMap
        case showPopulation
        case recording
    }
    
    var showDebugInfo = false
    var showWireframe = false
    var showPopulation = Preferences.showPopulation
    var terrainStyle: TerrainType = Preferences.preferedTerrain
    var gearStyle: GearType = Preferences.preferedGear
    var cameraType: CameraType = .firstPerson
    var aboveGround: Float = 1.0
    var location: GeoLocation?
    var gpxFileUrl: URL?
    var showTrack = false
    var customMapUrl: URL?

    func renderTerrainPopulation(miniView: Bool) -> Bool
    {
        let properTerrain = true // self.terrainStyle == .map || self.terrainStyle == .enhanced || self.terrainStyle == .custom        
        let mainIsFirstPersonCamera = self.cameraType == .firstPerson
        if miniView {
            return mainIsFirstPersonCamera ? false : properTerrain
        }
        else {
            return mainIsFirstPersonCamera ? properTerrain : false
        }
    }
    
    func renderSkybox(miniView: Bool) -> Bool
    {
        let mainIsFirstPersonCamera = self.cameraType == .firstPerson
        if miniView {
            return mainIsFirstPersonCamera ? false : true
        }
        else {
            return true
        }
    }
}

struct InputControlInfo
{
    let direction: float2
    let didTranslate: Bool
    let didRotate: Bool
    let translationSpeed: Float
    
    init()
    {
        self.direction = float2(repeating: 0)
        self.didTranslate = false
        self.didRotate = false
        self.translationSpeed = 0
    }
    
    init(direction: float2, didTranslate translate: Bool, didRotate rotate: Bool, translationSpeed speed: Float)
    {
        self.direction = direction
        self.didTranslate = translate
        self.didRotate = rotate
        self.translationSpeed = speed
    }
    
    func didTranslateOrRotate() -> Bool
    {
        return self.didTranslate || self.didRotate
    }
}

protocol InputDeviceDelegate
{
    func moveEvent(delta: float3, location: float2)
}

struct Globals
{
    struct Colors
    {
        #if os(macOS)
        static let red = CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        static let yellow = CGColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 1.0)
        static let purple = CGColor(red: 1.0, green: 0.0, blue: 1.0, alpha: 1.0)
        #else
        static let red = CGColor(srgbRed: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        static let yellow = CGColor(srgbRed: 1.0, green: 1.0, blue: 0.0, alpha: 1.0)
        static let purple = CGColor(srgbRed: 1.0, green: 0.0, blue: 1.0, alpha: 1.0)
        #endif
    }
    
    struct FSNames
    {
        static let satelliteImagesFolder = "satelliteImages"
        static let heightmapsFolder = "heightmaps"
        static let terrainFeaturesFolder = "terrainFeatures"
        static let streetsFolder = "streetImages"
        static let tracksFolder = "trackImages"
        static let debugFolder = "debug"
    }

    static let longDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .long
        return formatter
    }()
    
    static let longDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()
    
    struct Mapbox
    {
        static let host = "https://api.mapbox.com/v4"
        static let host2 = "https://api.mapbox.com/styles/v1/mapbox"
        static let accessToken = "the token"
        static let heightmapApi = "mapbox.terrain-rgb"
        static let satelliteApi = "mapbox.satellite"
        static let terrainFeaturesApi = "mapbox.mapbox-terrain-v2"
        static let streetsApi = "outdoors-v11"
        static let zoom = 15
        static let heightmapDimension = "" // = 256,  "@2x" = 512
        static let satelliteDimension = "@2x" // = 256,  "@2x" = 512
        static let terrainFeaturesDimension = "" // = 256,  "@2x" = 512
        static let streetDimension = "@2x" // = 256,  "@2x" = 512
        static let streetDoubleDimension = "" // "" = streetDimension,  "/512" = 2 x streetDimension

        
        static func heightmapUrlString(forTile tile: Tile) -> String
        {
            return "\(host)/\(heightmapApi)/\(tile.zoom)/\(tile.x)/\(tile.y)\(heightmapDimension).pngraw?access_token=\(accessToken)"
        }
        
        static func satelliteUrlString(forTile tile: Tile) -> String
        {
            return "\(host)/\(satelliteApi)/\(tile.zoom)/\(tile.x)/\(tile.y)\(satelliteDimension).pngraw?access_token=\(accessToken)"
        }
        
        static func terrainFeaturesUrlString(forTile tile: Tile) -> String
        {
            return "\(host)/\(terrainFeaturesApi)/\(tile.zoom)/\(tile.x)/\(tile.y)\(terrainFeaturesDimension).pngraw?access_token=\(accessToken)"
        }
        
        static func streetsUrlString(forTile tile: Tile) -> String
        {
            return "\(host2)/\(streetsApi)/tiles\(streetDoubleDimension)/\(tile.zoom)/\(tile.x)/\(tile.y)\(streetDimension)?access_token=\(accessToken)"
        }
    }
    
    struct ControlRange
    {
        static let heightControlMin = 1
        static let heightControlMax = 30
    }
    
    struct GUI {
        static let clearLocationNameAfterSeconds: Double = 5
    }
    
    struct Config {
        static var hasMaxPopulation = true
        static var hasMiniView = true
        static var useShadows = true
        #if DEBUG
        static var displayFps = true
        #else
        static var displayFps = false
        #endif
    }
}
