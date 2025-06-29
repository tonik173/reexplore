//
//  SecureStore.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 09.01.21.
//  Copyright © 2021 n3xd software studios ag. All rights reserved.
//
import Foundation

enum IapFeatures
{
    case gpxUpload
}

struct Wallet: Decodable, Encodable, Equatable, CustomStringConvertible
{
    var description: String {
        return "version: \(version), gpxUploadsTotal: \(gpxUploadsTotal), checksum: \(checksum)"
    }
    
    static func == (lhs: Wallet, rhs: Wallet) -> Bool {
        return lhs.checksum == rhs.checksum
    }
    
    fileprivate let version: UInt8
    fileprivate var checksum: Int64
    
    fileprivate var gpxUploadsTotal: UInt16 {
        didSet {
            checksum = Wallet.calculateChecksum(version: version, gpxUploadsTotal: gpxUploadsTotal)
        }
    }
    
    init()
    {
        version = 1
        gpxUploadsTotal = 1
        checksum = 0
    }
    
    fileprivate static func calculateChecksum(version: UInt8, gpxUploadsTotal: UInt16) -> Int64
    {
        let val1 = (125*version).hashValue % (Int.max / 2)
        let val2 = (173*gpxUploadsTotal).hashValue % (Int.max / 2)
        let val = Int64(val1 + val2)
        return val
    }
    
    fileprivate static func validate(wallet: Wallet) -> Bool
    {
        let valid = wallet.checksum == Wallet.calculateChecksum(version: wallet.version, gpxUploadsTotal: wallet.gpxUploadsTotal)
        return valid
    }
}

struct SecureStore
{
    static func isAvailableForTrial(feature: IapFeatures) -> Bool
    {
        let wallet = SecureStore.read()
        guard Wallet.validate(wallet: wallet) else { return false }
        switch feature {
            case .gpxUpload: return wallet.gpxUploadsTotal < 2
        }
    }
    
    static func used(feature: IapFeatures)
    {
        var wallet = SecureStore.read()
        switch feature {
            case .gpxUpload: wallet.gpxUploadsTotal += 1
        }
        SecureStore.write(wallet: wallet)
    }
    
    fileprivate static func read() -> Wallet
    {
        let decoder = JSONDecoder()

        // try to get the wallet from the hidden file
        var walletFile: Wallet?
        do {
            if let url = getDocumentsDirectory() {
                let dataFile = try Data(contentsOf: url)
                walletFile = try decoder.decode(Wallet.self, from: dataFile)
            }
        }
        catch {}
        
        // try to get the wallet from the prefs
        var walletPrefs: Wallet?
        let json = Preferences.secureStore
        if json.count > 0 {
            do {
                if let dataPrefs = Data(base64Encoded: json) {
                    walletPrefs = try decoder.decode(Wallet.self, from: dataPrefs)
                }
            }
            catch {}
        }
        
        if walletFile == .none && walletPrefs == .none {
            Log.iap("Both wallet entries do not exist. initial condition.")
            var initialWallet = Wallet()
            initialWallet.checksum = Wallet.calculateChecksum(version: 1, gpxUploadsTotal: 1)
            SecureStore.write(wallet: initialWallet)
            return initialWallet
        }
        else if let walletFile = walletFile, let walletPrefs = walletPrefs {
            if walletFile == walletPrefs {
                Log.iap("Both wallet entries are here and are the same: \(String(describing: walletPrefs))")
                return walletPrefs
            }
        }
        else {
            Log.iap("One wallet entry is missing. User tampered.")
            return Wallet()
        }
 
        Log.iap("Both entries are here but are not the same. User tampered.\n\(String(describing: walletFile))\n\(String(describing: walletPrefs))")
        return Wallet()
    }

    fileprivate static func write(wallet: Wallet)
    {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(wallet)
            if let url = getDocumentsDirectory() {
                try data.write(to: url)
            }
            Preferences.secureStore = data.base64EncodedString()
        }
        catch {
            Log.error(error.localizedDescription)
        }
        Log.iap("wallet saved \(wallet)")
    }
    
    fileprivate static func getDocumentsDirectory() -> URL?
    {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = (paths[0].absoluteString as NSString).appendingPathComponent(".reexplore")
        return URL(string: documentsDirectory)
    }
    
    static func clean()
    {
        let fileManager = FileManager.default
        if let url = getDocumentsDirectory() {
            do { try fileManager.removeItem(atPath: url.path) } catch { }
            Preferences.secureStore = ""
            Log.iap("Secure store cleaned (in Debug mode only)")
        }
    }
}
