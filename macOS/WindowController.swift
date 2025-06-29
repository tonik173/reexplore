//
//  WindowController.swift
//  Reexplore-macOS
//
//  Created by Toni Kaufmann on 15.09.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import Cocoa
import CoreLocation

private extension NSToolbarItem.Identifier {
    static let terrainStyle: NSToolbarItem.Identifier = NSToolbarItem.Identifier(rawValue: "TerrainStyle")
    static let locationChooser: NSToolbarItem.Identifier = NSToolbarItem.Identifier(rawValue: "LocationChooser")
    static let gpxChooser: NSToolbarItem.Identifier = NSToolbarItem.Identifier(rawValue: "GpxChooser")
    static let cameraChooser: NSToolbarItem.Identifier = NSToolbarItem.Identifier(rawValue: "CameraChooser")
    static let debugInfo: NSToolbarItem.Identifier = NSToolbarItem.Identifier(rawValue: "DebugInfo")
}

class WindowController: NSWindowController, NSToolbarDelegate, MapViewControllerDelegate, InAppPurchaseController
{

    private lazy var openPanel: NSOpenPanel = {
        let panel = NSOpenPanel()
        configure(panel)
        return panel
    }()
    
    private lazy var savePanel: NSSavePanel = {
        let panel = NSSavePanel()
        configure(panel)
        return panel
    }()
    
    @IBOutlet var toolbar: NSToolbar!
    
    // terrain style
    @IBOutlet var terrainSegmentView: NSView!
    @IBOutlet var terrainProgressView: NSProgressIndicator!
    @IBOutlet var terrainStyleChooser: NSSegmentedControl!
    
    // navigation
    @IBOutlet var mapView: NSView!
    @IBOutlet var locationChooserBtn: NSButton!
    
    // track
    @IBOutlet var gpxChooserView: NSView!
    @IBOutlet var uploadGpxBtn: NSButton!
    @IBOutlet var showGpxCheckbox: NSButton!
    @IBOutlet var trackBackBtn: NSButton!
    @IBOutlet var trackRecordBtn: NSButton!
    @IBOutlet var trackFlagBtn: NSButton!
    var recordingAttrBtnTitle: NSAttributedString!
    var recordAttrBtnTitle: NSAttributedString!

    // Camera Chooser
    @IBOutlet var cameraChooserView: NSView!
    @IBOutlet var cameraTypeChooser: NSSegmentedControl!
    @IBOutlet var aboveGroundSlider: NSSlider!
    
    // debug info
    @IBOutlet var debugInfoView: NSView!
    @IBOutlet var tileInfoCheckbox: NSButton!
    @IBOutlet var wireframeCheckbox: NSButton!
    
    override func awakeFromNib()
    {
        super.awakeFromNib()
        self.window?.tabbingMode = .disallowed
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        
        let recordingAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.red]
        recordingAttrBtnTitle = NSMutableAttributedString(string: "recording".localized, attributes: recordingAttributes)
        let recordAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.darkGray]
        recordAttrBtnTitle = NSMutableAttributedString(string: "record".localized, attributes: recordAttributes)
        trackRecordBtn.attributedTitle = recordAttrBtnTitle
        
        NotificationCenter.default.addObserver(forName: Notifications.updateSegment, object: nil, queue: nil) { (notification) in
            if let segmentIndex = Notifications.payload(forUpdateSegmentNotification: notification) {                
                self.trackBackBtn.title = segmentIndex
            }
        }
    }
    
    override func windowDidLoad()
    {
        super.windowDidLoad()
        
        if let vc = self.contentViewController as? ViewController {
            switch vc.gameConfig.terrainStyle {
            case .map:
                terrainStyleChooser.selectSegment(withTag: 0)
            case .satellite:
                terrainStyleChooser.selectSegment(withTag: 1)
            case .mixed:
                terrainStyleChooser.selectSegment(withTag: 2)
            case .enhanced:
                terrainStyleChooser.selectSegment(withTag: 3)
            case .custom:
                terrainStyleChooser.selectSegment(withTag: 4)
            }
            terrainStyleChooser.segmentCount = 3
            
            switch vc.gameConfig.cameraType {
            case .firstPerson:
                cameraTypeChooser.selectSegment(withTag: 0)
            case .orthograhic:
                cameraTypeChooser.selectSegment(withTag: 1)
            }
            cameraTypeChooser.segmentCount = 2
            
            tileInfoCheckbox.state = vc.gameConfig.showDebugInfo ? .on : .off
            wireframeCheckbox.state = vc.gameConfig.showWireframe ? .on : .off
            aboveGroundSlider.floatValue = vc.gameConfig.aboveGround
            aboveGroundSlider.minValue = Double(Globals.ControlRange.heightControlMin)
            aboveGroundSlider.maxValue = Double(Globals.ControlRange.heightControlMax)
        }
        
        showMovie()
        
        NotificationCenter.default.addObserver(forName: Notifications.updateSegment, object: nil, queue: nil) { (notification) in
            if let segmentIndex = Notifications.payload(forUpdateSegmentNotification: notification) {
                
                self.trackBackBtn.title = segmentIndex
            }
        }
    }
    
    func showMovie()
    {
        if Preferences.showIntroMovie {
            Log.gui("show movie")
            let scene = NSStoryboard.SceneIdentifier("introViewController")
            if let viewControllerObject = self.storyboard?.instantiateController(withIdentifier: scene),
               let viewController = viewControllerObject as? NSViewController {
                self.contentViewController?.presentAsModalWindow(viewController)
            }
        }
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?)
    {
        if let vc = segue.destinationController as? MapViewController {
            vc.delegate = self
        }
    }
    
    private func adjustGpxCheckbox(withTitle title: String)
    {
        if let vc = self.contentViewController as? ViewController {
            if let _ = vc.gameConfig.gpxFileUrl {
                self.showGpxCheckbox.state = vc.gameConfig.showTrack ? .on : .off
                self.showGpxCheckbox.title = title
            }
        }
    }
    
    @IBAction func changeTerrainStyleBySegment(_ sender: NSSegmentedControl)
    {
        if let vc = self.contentViewController as? ViewController {
            var config = vc.gameConfig
            self.terrainProgressView.startAnimation(sender)
            for i in 0..<sender.segmentCount {
                sender.setEnabled(false, forSegment: i)
            }
            switch sender.selectedTag() {
            case 1:
                config.terrainStyle = .satellite
            case 2:
                config.terrainStyle = .mixed
            case 3:
                config.terrainStyle = .enhanced
            case 4:
                config.terrainStyle = .custom
            default:
                config.terrainStyle = .map
            }
            
            Preferences.preferedTerrain = config.terrainStyle
            
            vc.updateGameConfig(config, changed: .terrainStyle) {
                self.terrainProgressView.stopAnimation(sender)
                for i in 0..<sender.segmentCount {
                    sender.setEnabled(true, forSegment: i)
                }
                // disable last -> niy
                sender.setEnabled(true, forSegment: sender.segmentCount - 1)
            }
            
            Log.gui("change terrain style to to \(config.terrainStyle)")
        }
    }
    
    @IBAction func changeCameraTypeBySegment(_ sender: NSSegmentedControl)
    {
        if let vc = self.contentViewController as? ViewController {
            var config = vc.gameConfig
            switch sender.selectedTag() {
            case 1:
                config.cameraType = .orthograhic
            default:
                config.cameraType = .firstPerson
            }
            aboveGroundSlider.floatValue = config.aboveGround
            vc.updateGameConfig(config, changed: .cameraType) {}
            Log.gui("change camera to \(config.cameraType)")
        }
    }
    
    @IBAction func changeTerrainInfo(_ sender: NSButton)
    {
        if let vc = self.contentViewController as? ViewController {
            var config = vc.gameConfig
            config.showDebugInfo = sender.state == .on
            vc.updateGameConfig(config, changed: .debugInfo) { }
        }
    }
    
    @IBAction func changeWireframe(_ sender: NSButton)
    {
        if let vc = self.contentViewController as? ViewController {
            var config = vc.gameConfig
            config.showWireframe = sender.state == .on
            vc.updateGameConfig(config, changed: .debugWirefame) { }
        }
    }

    var product = InAppPurchaseProducts.AvailableProducts.gpxTrack
    
    @IBAction func uploadGpx(_ sender: Any)
    {
        Log.gui("about to upload gpx track")
        openPanel.beginSheetModal(for: self.window!) { [weak self] (modalResponse) in
            if modalResponse == .OK {
                if let vc = self?.contentViewController as? ViewController {
                    var config = vc.gameConfig
                    config.gpxFileUrl = self?.openPanel.url
                    vc.updateGameConfig(config, changed: .gpxFileUrl) { }

                    config.showTrack = true
                    vc.updateGameConfig(config, changed: .trackVisibility) { }

                    var name: String = "Display Track"
                    if let url = self?.openPanel.url {
                        if let trackname = GPXFileParser.trackName(forUrl: url) {
                            name = trackname
                        }
                        
                        SecureStore.used(feature: .gpxUpload)
                    }
                    self?.adjustGpxCheckbox(withTitle: name)
                    
                    Log.gui("track \(name) uploaded")
                }
            }
        }
    }
    
    @IBAction func gpxDisplayChanged(_ sender: NSButton)
    {
        Log.gui("toggle gpx display")
        if let vc = self.contentViewController as? ViewController {
            var config = vc.gameConfig
            config.showTrack = sender.state == .on
            vc.updateGameConfig(config, changed: .trackVisibility) { }
        }
    }
    
    @IBAction func aboveGroundChanged(_ sender: NSSlider)
    {
        if let vc = self.contentViewController as? ViewController {
            var config = vc.gameConfig
            config.aboveGround = sender.floatValue
            vc.updateGameConfig(config, changed: .aboveGround) { }
            Log.gui("aboveGroundChanged to \(sender.floatValue)")
        }
    }
    
    @IBAction func record(_ sender: NSButton)
    {
        if sender.state == .on {
            Log.gui("record track")
            sender.attributedTitle = self.recordingAttrBtnTitle
            if let vc = self.contentViewController as? ViewController {
                vc.startRecordingTrack()
            }
        }
        else {
            Log.gui("save record track")
            sender.attributedTitle = recordAttrBtnTitle
            if let vc = self.contentViewController as? ViewController {
                if let xml = vc.stopRecordingTrack() {
                    self.save(xml: xml)
                }
            }
        }
    }
    
    @IBAction func flagLocation(_ sender: Any)
    {
        Log.gui("flagLocation")
        if let vc = self.contentViewController as? ViewController {
            vc.startNewTrackSegment()
        }
    }
    
    @IBAction func trackBack(_ sender: NSButton)
    {
        Log.gui("trackBack")
        if let vc = self.contentViewController as? ViewController {
            vc.backToTrackSegmentStart()
       }
    }
    
    fileprivate func configure(_ panel: NSOpenPanel)
    {
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.resolvesAliases = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Open GPX File"
        panel.allowedFileTypes = ["gpx"]
        panel.allowsOtherFileTypes = true
    }
    
    fileprivate func configure(_ panel: NSSavePanel)
    {
        panel.prompt = "Save GPX File"
        panel.allowedFileTypes = ["gpx"]
        panel.canCreateDirectories = true
    }
    
    fileprivate func save(xml: String)
    {
        savePanel.beginSheetModal(for: self.window!) { [weak self] (modalResponse) in
            if modalResponse == .OK {
                if let url = self?.savePanel.url {
                    do {
                    try xml.write(to: url, atomically: true, encoding: .utf8)
                    }
                    catch let error as NSError {
                        Log.error(error.localizedDescription)
                    }
                }
            }
        }
    }
        
    // MARK: - MapViewControllerDelegate
    
    func didChooseLocation(location: CLLocationCoordinate2D)
    {
        if let vc = self.contentViewController as? ViewController {
            var config = vc.gameConfig
            config.location = GeoLocation(lat: location.latitude, lon: location.longitude)
            vc.updateGameConfig(config, changed: .location) { }
        }
    }
    
    // MARK: - NSToolbarDelegate
    
    /** Custom factory method to create NSToolbarItems.
     
     All NSToolbarItems have a unique identifier associated with them, used to tell your
     delegate/controller what toolbar items to initialize and return at various points.
     Typically, for a given identifier, you need to generate a copy of your "master" toolbar item,
     and return. The function creates an NSToolbarItem with a bunch of NSToolbarItem parameters.
     
     It's easy to call this function repeatedly to generate lots of NSToolbarItems for your toolbar.
     
     The label, palettelabel, toolTip, action, and menu can all be nil, depending upon what
     you want the item to do.
     */
    fileprivate func customToolbarItem(
        itemForItemIdentifier itemIdentifier: String,
        label: String,
        paletteLabel: String,
        toolTip: String,
        itemContent: AnyObject) -> NSToolbarItem?
    {
        let toolbarItem = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier(rawValue: itemIdentifier))
        
        toolbarItem.label = label
        toolbarItem.paletteLabel = paletteLabel
        toolbarItem.toolTip = toolTip
        toolbarItem.target = self
        
        // Set the right attribute, depending on if we were given an image or a view.
        if itemContent is NSImage {
            if let image = itemContent as? NSImage {
                toolbarItem.image = image
            }
        } else if itemContent is NSView {
            if let view = itemContent as? NSView {
                toolbarItem.view = view
            }
        } else {
            assertionFailure("Invalid itemContent: object")
        }
        
        // We actually need an NSMenuItem here, so we construct one.
        let menuItem: NSMenuItem = NSMenuItem()
        menuItem.submenu = nil
        menuItem.title = label
        toolbarItem.menuFormRepresentation = menuItem
        
        return toolbarItem
    }
    
    /** This is an optional delegate function, called when a new item is about to be added to the toolbar.
     This is a good spot to set up initial state information for toolbar items, particularly items
     that you don't directly control yourself (like with NSToolbarPrintItemIdentifier).
     The notification's object is the toolbar, and the "item" key in the userInfo is the toolbar item
     being added.
     */
    func toolbarWillAddItem(_ notification: Notification) {
        let userInfo = notification.userInfo!
        if let addedItem = userInfo["item"] as? NSToolbarItem {
            let itemIdentifier = addedItem.itemIdentifier
            if itemIdentifier == .print {
                addedItem.toolTip = NSLocalizedString("print string", comment: "")
                addedItem.target = self
            }
        }
    }
    
    /**    NSToolbar delegates require this function.
     It takes an identifier, and returns the matching NSToolbarItem. It also takes a parameter telling
     whether this toolbar item is going into an actual toolbar, or whether it's going to be displayed
     in a customization palette.
     */
    /// - Tag: ToolbarItemForIdentifier
    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem?
    {
        var toolbarItem: NSToolbarItem = NSToolbarItem()
        
        /**    Create a new NSToolbarItem, and then go through the process of setting up its
         attributes from the master toolbar item matching that identifier in the dictionary of items.
         */
        if itemIdentifier == NSToolbarItem.Identifier.terrainStyle {
            toolbarItem = customToolbarItem(itemForItemIdentifier: NSToolbarItem.Identifier.terrainStyle.rawValue,
                                            label: NSLocalizedString("Terrain Style", comment: ""),
                                            paletteLabel: NSLocalizedString("Terrain Style", comment: ""),
                                            toolTip: NSLocalizedString("Choose between different terrains", comment: ""),
                                            itemContent: terrainSegmentView)!
        }
        else if itemIdentifier == NSToolbarItem.Identifier.cameraChooser {
            toolbarItem = customToolbarItem(itemForItemIdentifier: NSToolbarItem.Identifier.cameraChooser.rawValue,
                                            label: NSLocalizedString("Camera Type", comment: ""),
                                            paletteLabel: NSLocalizedString("Camera Type", comment: ""),
                                            toolTip: NSLocalizedString("Choose between different view angles", comment: ""),
                                            itemContent: cameraChooserView)!
        }
        else if itemIdentifier == NSToolbarItem.Identifier.locationChooser {
            toolbarItem = customToolbarItem(itemForItemIdentifier: NSToolbarItem.Identifier.locationChooser.rawValue,
                                            label: NSLocalizedString("Map", comment: ""),
                                            paletteLabel: NSLocalizedString("Map", comment: ""),
                                            toolTip: NSLocalizedString("Select the location of interest", comment: ""),
                                            itemContent: mapView)!
        }
        else if itemIdentifier == NSToolbarItem.Identifier.gpxChooser {
            toolbarItem = customToolbarItem(itemForItemIdentifier: NSToolbarItem.Identifier.gpxChooser.rawValue,
                                            label: NSLocalizedString("Track", comment: ""),
                                            paletteLabel: NSLocalizedString("Track", comment: "123"),
                                            toolTip: NSLocalizedString("Upload a track to view on the map", comment: ""),
                                            itemContent: gpxChooserView)!
        }
        else if itemIdentifier == NSToolbarItem.Identifier.debugInfo {
            toolbarItem = customToolbarItem(itemForItemIdentifier: NSToolbarItem.Identifier.debugInfo.rawValue,
                                            label: NSLocalizedString("Developer", comment: ""),
                                            paletteLabel: NSLocalizedString("Developer", comment: ""),
                                            toolTip: NSLocalizedString("Developer settings", comment: ""),
                                            itemContent: debugInfoView)!
        }
        
        return toolbarItem
    }
    
    /** NSToolbar delegates require this function. It returns an array holding identifiers for the default
     set of toolbar items. It can also be called by the customization palette to display the default toolbar.
     
     Note: That since our toolbar is defined from Interface Builder, an additional separator and customize
     toolbar items will be automatically added to the "default" list of items.
     */
    /// - Tag: DefaultIdentifiers
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier]
    {
        #if DEBUG
        return [.terrainStyle,
                .cameraChooser,
                .space,
                .gpxChooser,
                .locationChooser,
                .flexibleSpace,
                .debugInfo
        ]
        #else
        return [.terrainStyle,
                .cameraChooser,
                .flexibleSpace,
                .locationChooser,
                .gpxChooser
        ]
        #endif
    }
    
    /** NSToolbar delegates require this function. It returns an array holding identifiers for all allowed
     toolbar items in this toolbar. Any not listed here will not be available in the customization palette.
     */
    /// - Tag: AllowedToolbarItems
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier]
    {
        #if DEBUG
        return [ .terrainStyle,
                 .cameraChooser,
                 .space,
                 .gpxChooser,
                 .locationChooser,
                 .flexibleSpace,
                 .debugInfo,
        ]
        #else
        return [ .terrainStyle,
                 .cameraChooser,
                 .flexibleSpace,
                 .gpxChooser,
                 .locationChooser,
        ]
        #endif
    }
}
