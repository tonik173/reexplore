//
//  PreferencesViewController.swift
//  Reexplore-macOS
//
//  Created by Toni Kaufmann on 28.12.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import Cocoa

class PreferencesViewController: NSViewController
{
    @IBOutlet weak var populateTerrainBtn: NSButton!
    @IBOutlet weak var showIntroMovieBtn: NSButton!
    @IBOutlet weak var gearSwitch: NSSegmentedControl!
    @IBOutlet weak var versionLabel: NSTextField!
    @IBOutlet weak var debugControlsView: NSStackView!
    @IBOutlet weak var displayFpsBtn: NSButton!
    @IBOutlet weak var useShadowsBtn: NSButton!
    @IBOutlet weak var maxPopulationBtn: NSButton!
    
    #if DEBUG
    fileprivate let showDebugControls = true
    #else
    fileprivate let showDebugControls = false
    #endif
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.populateTerrainBtn.state = Preferences.showPopulation ? .on : .off
        self.showIntroMovieBtn.state = Preferences.showIntroMovie ? .on : .off
        
        self.debugControlsView.isHidden = !showDebugControls
        self.displayFpsBtn.state = Globals.Config.displayFps ? .on : .off
        self.useShadowsBtn.state = Globals.Config.useShadows ? .on : .off
        self.maxPopulationBtn.state = Globals.Config.hasMaxPopulation ? .on : .off

        switch Preferences.preferedGear {
        case .runner:
            self.gearSwitch.setSelected(true, forSegment: 0)
            self.gearSwitch.setSelected(false, forSegment: 1)
        case .biker:
            self.gearSwitch.setSelected(false, forSegment: 0)
            self.gearSwitch.setSelected(true, forSegment: 1)
        }
        
        let versionText = Platform.compileVersionString(includeBundleNumber: true, withBuildDate: true)
        self.versionLabel.stringValue = versionText
    }
    
    @IBAction func populateTerrain(_ sender: NSButton)
    {
        Preferences.showPopulation = sender.state == .on
    }
    
    @IBAction func showIntroMovie(_ sender: NSButton)
    {
        Preferences.showIntroMovie = sender.state == .on
    }
    
    @IBAction func switchedGear(_ sender: NSSegmentedControl)
    {
        Preferences.preferedGear = sender.isSelected(forSegment: 0) ? .runner : .biker
    }
    
    @IBAction func displayFps(_ sender: NSButton)
    {
        Globals.Config.displayFps = sender.state == .on
    }
    
    @IBAction func useShadows(_ sender: NSButton)
    {
        Globals.Config.useShadows = sender.state == .on
    }
    
    @IBAction func maxPopulation(_ sender: NSButton)
    {
        Globals.Config.hasMaxPopulation = sender.state == .on
    }
    
    @IBAction func toggleDebugControls(_ sender: Any)
    {
        self.debugControlsView.isHidden = !self.debugControlsView.isHidden
    }
    
    @IBAction func clearStore(_ sender: NSClickGestureRecognizer)
    {
        SecureStore.clean()
    }
}
