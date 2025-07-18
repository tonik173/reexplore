//
//  LocalClasses.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 16.06.2020.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import Cocoa
import MetalKit

@NSApplicationMain

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate
{
    @IBOutlet weak var viewMenu: NSMenu!
    @IBOutlet weak var actionMenu: NSMenu!
    @IBOutlet weak var navigationMenu: NSMenu!
    @IBOutlet weak var trackMenu: NSMenu!
    
    func applicationDidFinishLaunching(_ aNotification: Notification)
    {
        Preferences.registerDefaults()
        
        let unusedMenu = NSMenu(title: "Unused")
        NSApplication.shared.helpMenu = unusedMenu
        
        self.viewMenu.delegate = self
        self.actionMenu.delegate = self
        self.navigationMenu.delegate = self
        self.trackMenu.delegate = self
    }
    
    func applicationWillTerminate(_ aNotification: Notification)
    {
    }
    
    func menuWillOpen(_ menu: NSMenu)
    {
        if let window = NSApplication.shared.mainWindow {
            if let vc = window.windowController?.contentViewController as? LocalViewController {
                if menu == self.viewMenu {
                    vc.adjustViewMenu(menu)
                }
                else if menu == self.actionMenu {
                    vc.adjustActionMenu(menu)
                }
                else if menu == self.navigationMenu {
                    vc.adjustNavigationMenu(menu)
                }
                else if menu == self.trackMenu {
                    vc.adjustTrackMenu(menu)
                }
            }
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

class LocalViewController: NSViewController
{
    weak var infoLabel: NSTextField!
    weak var miniMapView: MiniGameView?
    
    fileprivate var masl: Int = 0
    fileprivate var loadingProgressInPercent: Int = 0
    fileprivate var place = ""
    fileprivate var location = ""
    fileprivate var instrumentsInfo = ""
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.infoLabel = self.view.viewWithTag(1001) as? NSTextField
        self.infoLabel.stringValue = "loading height map…"
        
        for view in self.view.subviews {
            if let miniMapView = view as? MiniGameView {
                self.miniMapView = miniMapView
            }
        }
    }
    
    func setHeight(meterAboveSeeLevel masl: Int)
    {
        self.masl = masl
        self.updateInfoLabel()
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
        
        if let gameview = self.view as? GameView {
            gameview.geolocation = self.location
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
    
    fileprivate func updateInfoLabel()
    {
        if let gameview = self.view as? GameView {
            let placeInfo = self.place.count > 0 ? "\(place), " : ""
            let location = self.location.count > 0 ? "\n\(self.location)" : ""
            let measure = Globals.Config.displayFps ? "\n\(self.instrumentsInfo), s:\(gameview.speed)" : ""
            if loadingProgressInPercent == 100 {
                self.infoLabel.stringValue = "\(placeInfo)\(self.masl) m a.s.l.\(location)\(measure) "
            }
            else {
                self.infoLabel.stringValue = "\(placeInfo)\(self.masl) m a.s.l.\(location)\(measure)\n\(self.loadingProgressInPercent)%"
            }
        }
    }
    
    
    // MARK: - View menu handling

    fileprivate func adjustViewMenu(_ menu: NSMenu)
    {
        
        if let vc = self as? ViewController {
            // terrain
            if let mapMenuItem = menu.item(withIdentifier: NSUserInterfaceItemIdentifier("map")),
               let sateliteMenuItem = menu.item(withIdentifier: NSUserInterfaceItemIdentifier("satelite")),
               let mixedMenuItem = menu.item(withIdentifier: NSUserInterfaceItemIdentifier("mixed")) {
                switch vc.gameConfig.terrainStyle {
                case .map:
                    mapMenuItem.state = .on
                    sateliteMenuItem.state = .off
                    mixedMenuItem.state = .off
                case .satellite:
                    mapMenuItem.state = .off
                    sateliteMenuItem.state = .on
                    mixedMenuItem.state = .off
                case .mixed:
                    mapMenuItem.state = .off
                    sateliteMenuItem.state = .off
                    mixedMenuItem.state = .on
                case .enhanced:
                    mapMenuItem.state = .off
                    sateliteMenuItem.state = .off
                    mixedMenuItem.state = .off
                case .custom:
                    mapMenuItem.state = .off
                    sateliteMenuItem.state = .off
                    mixedMenuItem.state = .off
                }
            }
        
            // camera
            if let  fpvMenuItem = menu.item(withIdentifier: NSUserInterfaceItemIdentifier("3d")),
               let  orthoMenuItem = menu.item(withIdentifier: NSUserInterfaceItemIdentifier("ortho")) {
                switch vc.gameConfig.cameraType {
                case .firstPerson:
                    fpvMenuItem.state = .on
                    orthoMenuItem.state = .off
                case .orthograhic:
                    fpvMenuItem.state = .off
                    orthoMenuItem.state = .on
                }
            }
        }
    }
    
    @IBAction func chooseTerrain(_ sender: NSMenuItem)
    {
        Log.gui("choose menu terrain: \(sender.tag), \(String(describing: sender.identifier))")
        if let windowController = self.view.window?.windowController as? WindowController,
           let chooser = windowController.terrainStyleChooser {
            if let identifier = sender.identifier {
                switch identifier {
                case NSUserInterfaceItemIdentifier("map"):
                    chooser.selectedSegment = 0
                case NSUserInterfaceItemIdentifier("satelite"):
                    chooser.selectedSegment = 1
                case NSUserInterfaceItemIdentifier("mixed"):
                    chooser.selectedSegment = 2
                default:
                    Log.warn("Unknown menu identifier \(identifier.rawValue)")
                }
                windowController.changeTerrainStyleBySegment(chooser)
           }
        }
    }
    
    @IBAction func chooseCamera(_ sender: NSMenuItem)
    {
        Log.gui("choose menu camera: \(sender.tag), \(String(describing: sender.identifier))")
        if let windowController = self.view.window?.windowController as? WindowController,
           let chooser = windowController.cameraTypeChooser {
            if let identifier = sender.identifier {
                switch identifier {
                case NSUserInterfaceItemIdentifier("3d"):
                    chooser.selectedSegment = 0
                case NSUserInterfaceItemIdentifier("ortho"):
                    chooser.selectedSegment = 1
                default:
                    Log.warn("Unknown menu identifier \(identifier.rawValue)")
                }
                windowController.changeCameraTypeBySegment(chooser)
            }
        }
    }
    
    @IBAction func aboveGroundChanged(_ sender: NSMenuItem)
    {
        Log.gui("view height changed: \(sender.tag), \(String(describing: sender.identifier))")
        if let windowController = self.view.window?.windowController as? WindowController,
           let slider = windowController.aboveGroundSlider {
            if let identifier = sender.identifier {
                switch identifier {
                case NSUserInterfaceItemIdentifier("ground"):
                    slider.floatValue = max(Float(slider.minValue), slider.floatValue - 3)
                    sender.isEnabled = slider.floatValue != Float(slider.minValue)
                case NSUserInterfaceItemIdentifier("bird"):
                    slider.floatValue = min(Float(slider.maxValue), slider.floatValue + 3)
                    sender.isEnabled = slider.floatValue != Float(slider.maxValue)
                default:
                    Log.warn("Unknown menu identifier \(identifier.rawValue)")
                }
                windowController.aboveGroundChanged(slider)
            }
        }
    }
    
    
    // MARK: - Action menu handling

    fileprivate func adjustActionMenu(_ menu: NSMenu)
    {
    }
    
    @IBAction func speedChanged(_ sender: NSMenuItem)
    {
        Log.gui("speed changed: \(sender.tag), \(String(describing: sender.identifier))")
        if let vc = self as? ViewController,
           let identifier = sender.identifier {
            switch identifier {
            case NSUserInterfaceItemIdentifier("slow"):
                vc.post(key: KeyboardControl.minus)
            case NSUserInterfaceItemIdentifier("fast"):
                vc.post(key: KeyboardControl.plus)
            default:
                Log.warn("Unknown menu identifier \(identifier.rawValue)")
            }
            self.updateInfoLabel()
        }
    }
    
    @IBAction func directionChanged(_ sender: NSMenuItem)
    {
        Log.gui("direction changed: \(sender.tag), \(String(describing: sender.identifier))")
        if let vc = self as? ViewController,
           let identifier = sender.identifier {
            switch identifier {
            case NSUserInterfaceItemIdentifier("forward"):
                vc.post(key: KeyboardControl.w, durationInSeconds: 1.0)
            case NSUserInterfaceItemIdentifier("backward"):
                vc.post(key: KeyboardControl.s, durationInSeconds: 1.0)
            case NSUserInterfaceItemIdentifier("left"):
                vc.post(key: KeyboardControl.a, durationInSeconds: 0.3)
            case NSUserInterfaceItemIdentifier("right"):
                vc.post(key: KeyboardControl.d, durationInSeconds: 0.3)
            default:
                Log.warn("Unknown menu identifier \(identifier.rawValue)")
            }
        }
    }
    
    
    // MARK: - Navigation menu handling

    fileprivate func adjustNavigationMenu(_ menu: NSMenu)
    {
    }
    
    @IBAction func chooseLocation(_ sender: NSMenuItem)
    {
        Log.gui("choose location: \(sender.tag), \(String(describing: sender.identifier))")
        if let windowController = self.view.window?.windowController as? WindowController,
           let btn = windowController.locationChooserBtn {
            windowController.performSegue(withIdentifier: "showMap", sender: btn)
            self.resetElevation()
        }
    }

    @IBAction func openMap(_ sender: NSMenuItem)
    {
        Log.gui("open map: \(sender.tag), \(String(describing: sender.identifier))")
        if let gameView = self.view as? GameView {
            gameView.copyGPX(sender)
        }
    }
    
    
    // MARK: - Track menu handling
    
    fileprivate func adjustTrackMenu(_ menu: NSMenu)
    {
        if let vc = self as? ViewController {
            if let uploadMenuItem = menu.item(withIdentifier: NSUserInterfaceItemIdentifier("upload")),
               let showHideMenuItem = menu.item(withIdentifier: NSUserInterfaceItemIdentifier("showHideTrack")),
               let recordMenuItem = menu.item(withIdentifier: NSUserInterfaceItemIdentifier("record")),
               let setFlagMenuItem = menu.item(withIdentifier: NSUserInterfaceItemIdentifier("setFlag")),
               let backToFlagMenuItem = menu.item(withIdentifier: NSUserInterfaceItemIdentifier("backToFlag")) {

                uploadMenuItem.isEnabled = true
                showHideMenuItem.isEnabled = vc.gameConfig.gpxFileUrl != .none
                showHideMenuItem.title = vc.gameConfig.showTrack ? "hideTrack".localized : "showTrack".localized
                setFlagMenuItem.isEnabled = false
                backToFlagMenuItem.isEnabled = false
 
                if let windowController = self.view.window?.windowController as? WindowController,
                   let recordBtn = windowController.trackRecordBtn {
                    recordMenuItem.attributedTitle = recordBtn.attributedTitle
                    if recordBtn.state == .on {
                        setFlagMenuItem.isEnabled = recordBtn.state == .on
                        backToFlagMenuItem.isEnabled = recordBtn.state == .on
                        uploadMenuItem.isEnabled = recordBtn.state == .off
                        showHideMenuItem.isEnabled = recordBtn.state == .off
                    }
               }
            }
        }
    }
    
    @IBAction func uploadTrack(_ sender: NSMenuItem)
    {
        if let windowController = self.view.window?.windowController as? WindowController,
           let btn = windowController.uploadGpxBtn {
            windowController.uploadGpx(btn)
        }
    }
    
    @IBAction func showHideTrack(_ sender: NSMenuItem)
    {
        if let windowController = self.view.window?.windowController as? WindowController,
           let btn = windowController.showGpxCheckbox {
            windowController.gpxDisplayChanged(btn)
        }
    }
    
    @IBAction func recordTrack(_ sender: NSMenuItem)
    {
        if let windowController = self.view.window?.windowController as? WindowController,
           let btn = windowController.trackRecordBtn {
            btn.state = btn.state == .off ? .on : .off
            windowController.record(btn)
            self.resetElevation()
        }
    }
    
    @IBAction func setFlagTrack(_ sender: NSMenuItem)
    {
        if let windowController = self.view.window?.windowController as? WindowController,
           let btn = windowController.trackFlagBtn {
            windowController.flagLocation(btn)
        }
    }
    
    @IBAction func backToFlag(_ sender: NSMenuItem)
    {
        if let windowController = self.view.window?.windowController as? WindowController,
           let btn = windowController.trackFlagBtn {
            windowController.trackBack(btn)
        }
    }
    
    @IBAction func resetElevation(_ sender: NSMenuItem)
    {
        self.resetElevation()
    }
    
    fileprivate func resetElevation()
    {
        if let miniMapView = self.miniMapView  {
            miniMapView.reset()
        }
    }
}


// MARK: - NSMenu extension

extension NSMenu
{
    func item(withIdentifier identifier: NSUserInterfaceItemIdentifier) -> NSMenuItem?
    {
        for item in items {
            if item.identifier == identifier {
                return item
            }

            if let subItem = item.submenu?.item(withIdentifier: identifier) {
                return subItem
            }
        }

        return nil
    }
}
