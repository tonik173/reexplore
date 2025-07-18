//
//  Preferences.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 08.10.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import Foundation


struct Preferences
{
    struct Keys
    {
        static let lastUsedLocation = "lastUsedLocation"
        static let testMode = "testMode"
        static let showPopulation = "showPopulation"
        static let showIntroMovie = "showIntroMovie"
        static let preferedTerrain = "preferedTerrain"
        static let preferedGear = "preferedGear"
        static let secureStore = "secureStore"
        static let purchasedInAppPurchases = "purchasedInAppPurchases"
        static let preferedControlSide = "preferedControlSide"
    }
    
    // ------------------------------------------------------------------------------------------------------
    // MARK: - Initialization -
    // ------------------------------------------------------------------------------------------------------
    
    static func registerDefaults()
    {
        #if DEBUG
        let enableTestMode = true
        #else
        let enableTestMode = false
        #endif
 
        // let location = GeoLocation(lat: 47.10589, lon: 8.47518)  // Chiemen
        // let location = GeoLocation(lat: 47.049796, lon: 8.304282)  // Luzern
        // let location = GeoLocation(lat: 47.156140, lon: 8.511713) // Zug

        let defaultPreferences = [
            Keys.testMode: NSNumber(booleanLiteral: enableTestMode),
            Keys.showPopulation: NSNumber(booleanLiteral: true),
            Keys.showIntroMovie: NSNumber(booleanLiteral: true),
            Keys.preferedTerrain: NSNumber(value: TerrainType.map.rawValue),
            Keys.preferedGear: NSNumber(value: GearType.runner.rawValue),
            Keys.preferedControlSide: NSNumber(value: ControlSide.right.rawValue),
          Keys.secureStore: "",
            Keys.lastUsedLocation: ["lat": 47.156140, "lon": 8.511713],
            Keys.purchasedInAppPurchases: [:],
            ] as [String : Any]
        UserDefaults.standard.register(defaults: defaultPreferences)
    }
    
    static var testMode: Bool {
        get {
            let testMode = UserDefaults.standard.bool(forKey: Keys.testMode)
            return testMode
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.testMode)
            UserDefaults.standard.synchronize()
        }
    }
    
    static func logSettings()
    {
        if let lastUsedLocation = Preferences.lastUsedLocation {
            Log.misc("lastUsedLocation: \(lastUsedLocation)")
        }
        Log.misc("testMode: \(Preferences.testMode)")
    }
    
    static var showPopulation: Bool {
        get {
            let showPopulation = UserDefaults.standard.bool(forKey: Keys.showPopulation)
            return showPopulation
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.showPopulation)
            UserDefaults.standard.synchronize()
        }
    }
    
    static var showIntroMovie: Bool {
        get {
            let showIntroMovie = UserDefaults.standard.bool(forKey: Keys.showIntroMovie)
            return showIntroMovie
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.showIntroMovie)
            UserDefaults.standard.synchronize()
        }
    }
    
    static var preferedTerrain: TerrainType {
        get {
            let number = UserDefaults.standard.integer(forKey: Keys.preferedTerrain)
            if let preferedTerrain = TerrainType(rawValue: number) {
                return preferedTerrain
            }
            return .map
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.preferedTerrain)
            UserDefaults.standard.synchronize()
        }
    }
    
    static var preferedGear: GearType {
        get {
            let number = UserDefaults.standard.integer(forKey: Keys.preferedGear)
            if let preferedGear = GearType(rawValue: number) {
                return preferedGear
            }
            return .runner
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.preferedGear)
            UserDefaults.standard.synchronize()
        }
    }
    
    static var preferedControllerSide: ControlSide {
        get {
            let number = UserDefaults.standard.integer(forKey: Keys.preferedControlSide)
            if let preferedControlSide = ControlSide(rawValue: number) {
                return preferedControlSide
            }
            return .right
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.preferedControlSide)
            UserDefaults.standard.synchronize()
        }
    }
    
    static var secureStore: String {
        get {
            if let secureStore = UserDefaults.standard.string(forKey: Keys.secureStore) {
                return secureStore
            }
            return ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.secureStore)
            UserDefaults.standard.synchronize()
        }
    }
    
    // ------------------------------------------------------------------------------------------------------
    // MARK: - Communication
    // ------------------------------------------------------------------------------------------------------
    
    static var lastUsedLocation: GeoLocation? {
        get {
            if let location = UserDefaults.standard.object(forKey: Keys.lastUsedLocation) as? [String:Double],
               let lat = location["lat"],
               let lon = location["lon"] {
                return GeoLocation(lat: lat, lon: lon)
            }
            return .none
        }
        set {
            if let location = newValue {
                let geo = ["lat": location.lat, "lon": location.lon]
                UserDefaults.standard.setValue(geo, forKey: Keys.lastUsedLocation)
                UserDefaults.standard.synchronize()
            }
        }
    }

    // ------------------------------------------------------------------------------------------------------
    // MARK: - In-App Purchases -
    // ------------------------------------------------------------------------------------------------------

    static var purchasedInAppPurchases: [String:Bool] {
        get {
            let purchasedInAppPurchases = UserDefaults.standard.object(forKey: Keys.purchasedInAppPurchases) as? [String:Bool]
            return purchasedInAppPurchases ?? [:]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.purchasedInAppPurchases)
            UserDefaults.standard.synchronize()
        }
    }
}

// ------------------------------------------------------------------------------------------------------
// MARK: - End
// ------------------------------------------------------------------------------------------------------
