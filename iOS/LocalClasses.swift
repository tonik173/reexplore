//
//  LocalClasses.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 16.06.2020.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import UIKit
import MetalKit
import AVKit
import Firebase
import FirebaseAnalytics
import FirebasePerformance

protocol LocalViewControllerDelegate : AnyObject
{
    func didHitMenu()
    func didHitLocation()
    func didHitRider()
    func didHitMap()
    func didSwipeVertically(val: Float)
    func save(xml: String, withSourceView view: UIView);
    func chooseGpxFile()
    func hideGpxTrack()
}

class LocalViewController: UIViewController, LocalViewControllerDelegate, InAppPurchaseController, UIDocumentPickerDelegate
{
    weak var infoLabel: UILabel!
    weak var miniMapView: MiniGameView?
    weak var heightmapLoadingSpinner: UIActivityIndicatorView!
    
    fileprivate var masl: Int = 0
    fileprivate var loadingProgressInPercent: Int = 0
    fileprivate var place = ""
    fileprivate var location = ""
    fileprivate var instrumentsInfo = ""
    fileprivate var heightTrace: Trace?
    fileprivate var locationTrace: Trace?
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        if let gameView = self.view as? GameView {
            gameView.viewControllerDelegate = self
        }
        
        self.heightmapLoadingSpinner = self.view.viewWithTag(1002) as? UIActivityIndicatorView
        self.infoLabel = self.view.viewWithTag(1001) as? UILabel
        self.infoLabel.text = "loading height map…"
        
        for view in self.view.subviews {
            if let miniMapView = view as? MiniGameView {
                self.miniMapView = miniMapView
            }
        }
    }
    
    @IBAction func openGPX(_ sender: Any)
    {
        if self.location.count > 0 {
            let loc = location.replacingOccurrences(of: " ", with: "")
            Log.gui("coping GPX, invoke \(loc)")
            if let targetURL = NSURL(string: "maps://?ll=\(loc)&spn=0.005,0.005&t=h") {
                UIApplication.shared.open(targetURL as URL)
           }
        }
    }
    
    var inited = false
    fileprivate func finalizeLoading()
    {
        if !inited {
            self.heightmapLoadingSpinner.stopAnimating()
            inited = true
            
            showMovie()
        }
    }
    
    fileprivate func updateInfoLabel()
    {
        let placeInfo = self.place.count > 0 ? "\(place), " : ""
        let location = self.location.count > 0 ? "\n\(self.location)" : ""
        let measure = Globals.Config.displayFps ? "\n\(self.instrumentsInfo)" : ""
        if self.loadingProgressInPercent == 100 {
            self.infoLabel.text = "\(placeInfo)\(self.masl) m a.s.l.\(location)\(measure)"
        }
        else {
            self.infoLabel.text = "\(placeInfo)\(self.masl) m a.s.l.\(location)\(measure)\n\(self.loadingProgressInPercent)%"
            if self.loadingProgressInPercent > 50 {
                self.finalizeLoading()
            }
        }
    }
    
    func setHeight(meterAboveSeeLevel masl: Int)
    {
        self.masl = masl
        self.updateInfoLabel()
        
        if let trace = self.heightTrace {
            trace.stop()
            self.heightTrace = .none
        }
        else {
            self.heightTrace = Performance.startTrace(name: "heightUpdate")
        }
    }
    
    var timer: Timer?
    func setLocation(info: LocationInfo)
    {
        if let name = info.info {
            if let timer = timer {
                timer.invalidate()
                self.timer = .none
            }
            self.place = name
        }
        else {
            timer = Timer.scheduledTimer(withTimeInterval: Globals.GUI.clearLocationNameAfterSeconds, repeats: false) { (timer) in
                self.place = ""
            }
        }
        
        self.location = info.geoCord.description
        self.updateInfoLabel()
        
        if let trace = self.locationTrace {
            trace.stop()
            self.locationTrace = .none
        }
        else {
            self.locationTrace = Performance.startTrace(name: "locationUpdate")
        }
        
        if let miniMapView = self.miniMapView  {
            miniMapView.setLocation(info: info)
        }
    }
    
    func reloadElevationView(locations: [LocationInfo])
    {
        if let miniMapView = self.miniMapView  {
            miniMapView.reloadElevationView(locations: locations)
        }
    }
    
    func setLoadingProgress(inPercent progressInPercent: Int)
    {
        self.loadingProgressInPercent = progressInPercent
        self.updateInfoLabel()
    }
    
    func setInstrumentsInfo(info: MeasureInfo)
    {
        self.instrumentsInfo = "fps: \(info.fps)"
        self.updateInfoLabel()
    }
    
    func didHitMenu()
    {
        Log.gui("hit menu")
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: "settings"])
        if let settingsNavigationController = self.storyboard?.instantiateViewController(withIdentifier: "settingsNavigationController") as? SettingsNavigationController {
            self.present(settingsNavigationController, animated: true) { }
        }
    }

    func didHitLocation()
    {
        Log.gui("hit location")
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: "location-chooser"])
        if let mapNavigationController = self.storyboard?.instantiateViewController(withIdentifier: "mapNavigationController") as? MapNavigationController {
            self.present(mapNavigationController, animated: true) { }
        }
    }
    
    func showMovie()
    {
        if Preferences.showIntroMovie {
            Log.gui("show movie")
            if let avPlayerViewController = self.storyboard?.instantiateViewController(withIdentifier: "movieViewController") as? AVPlayerViewController {
                guard let path = Bundle.main.path(forResource: "help-ios", ofType: "mp4") else { return }
                let player = AVPlayer(url: URL(fileURLWithPath: path))
                avPlayerViewController.player = player
                avPlayerViewController.player?.play()
                self.present(avPlayerViewController, animated: true) { }
            }
        }
    }
    
    func didHitRider()
    {
        Log.gui("hit 3D display")
        if let vc = self as? ViewController {
            var config = vc.gameConfig
            config.cameraType = .firstPerson
            vc.updateGameConfig(config, changed: .cameraType) { }
        }
    }
    
    func didHitMap()
    {
        Log.gui("hit map display")
        if let vc = self as? ViewController {
            var config = vc.gameConfig
            config.cameraType = .orthograhic
            vc.updateGameConfig(config, changed: .cameraType) { }
        }
    }
    
    func didSwipeVertically(val: Float)
    {
        if let vc = self as? ViewController {
            var config = vc.gameConfig
            config.aboveGround = min(Float(Globals.ControlRange.heightControlMax), max(Float(Globals.ControlRange.heightControlMin), config.aboveGround + val * 20))
            Log.gui("swipe vertically \(val), above: \(config.aboveGround)")
            vc.updateGameConfig(config, changed: .aboveGround) { }
        }
    }
     
    func save(xml: String, withSourceView view: UIView)
    {
        let dateTimeString = Globals.longDateTimeFormatter.string(from: Date()).convertToValidFileName()
        let filenameUrl = PathHelpers.getDocumentsDirectory().appendingPathComponent("track-\(dateTimeString).gpx")
        do {
            try xml.write(to: filenameUrl, atomically: true, encoding: String.Encoding.utf8)
        } catch let error as NSError {
            Log.error("saving gpx failed. \(error.localizedDescription)")
        }
        
        var filesToShare = [Any]()
        filesToShare.append(filenameUrl)

        let activityViewController = UIActivityViewController(activityItems: filesToShare, applicationActivities: nil)
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = view
        }
        self.present(activityViewController, animated: true, completion: nil)
    }
    
    // ------------------------------------------------------------------------------------------------------
    // MARK: - InAppPurchaseController
    // ------------------------------------------------------------------------------------------------------

    let product = InAppPurchaseProducts.AvailableProducts.gpxTrack

    
    // ------------------------------------------------------------------------------------------------------
    // MARK: - GPX display
    // ------------------------------------------------------------------------------------------------------
    
    func hideGpxTrack()
    {
        if let vc = self as? ViewController {
            var config = vc.gameConfig
            config.showTrack = false
            vc.updateGameConfig(config, changed: .trackVisibility) { }
        }
    }
    
    var documentPickerController: UIDocumentPickerViewController!

    func chooseGpxFile()
    {
        let types = UTType.types(tag: "gpx", tagClass: UTTagClass.filenameExtension, conformingTo: nil)
        self.documentPickerController = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        documentPickerController.delegate = self
        documentPickerController.shouldShowFileExtensions = true
        documentPickerController.allowsMultipleSelection = false
        self.present(documentPickerController, animated: true, completion: nil)
    }
    
    // ------------------------------------------------------------------------------------------------------
    // MARK: - UIDocumentPickerDelegate
    // ------------------------------------------------------------------------------------------------------

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL])
    {
        if let trackURL = urls.first,
           let vc = self as? ViewController {
            var config = vc.gameConfig
            config.gpxFileUrl = trackURL
            vc.updateGameConfig(config, changed: .gpxFileUrl) { }
            
            config.showTrack = true
            vc.updateGameConfig(config, changed: .trackVisibility) { }
            
            var name: String = "Display Track"
            if let trackname = GPXFileParser.trackName(forUrl: trackURL) {
                name = trackname
            }
            
            SecureStore.used(feature: .gpxUpload)
            
            if let gameView = self.view as? GameView {
                gameView.didLoadTrack(withName: name)
            }
        }
        self.documentPickerController = .none
    }
}

// ------------------------------------------------------------------------------------------------------
// MARK: - AppDelegate
// ------------------------------------------------------------------------------------------------------

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate
{
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool
    {
        FirebaseApp.configure()
        Preferences.registerDefaults()
        // if let vc = window?.rootViewController as? LocalViewController {}
        return true
    }
}
