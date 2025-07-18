//
//  SettingsViewController.swift
//  Reexplore-iOS
//
//  Created by Toni Kaufmann on 27.09.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import UIKit
import MobileCoreServices
import UniformTypeIdentifiers

class SettingsNavigationController: UINavigationController
{
}

class SettingsViewController: UITabBarController
{
    @IBAction func close(_ sender: UIBarButtonItem)
    {
        self.dismiss(animated: true) { }
    }
}

class DisplayViewController: BaseSettingsViewController
{
    @IBOutlet weak var terrainChooser: UISegmentedControl!
    @IBOutlet weak var playIntroSwitch: UISwitch!
    @IBOutlet weak var playIntroLabel: UILabel!
    @IBOutlet weak var showPopulationSwitch: UISwitch!
    @IBOutlet weak var shoPopulationLabel: UILabel!
    @IBOutlet weak var gearTypeChooser: UISegmentedControl!
    @IBOutlet weak var versionLabel: UILabel!
    @IBOutlet weak var controllerSideSwitch: UISegmentedControl!
    
    @IBOutlet weak var debugControlView: UIStackView!
    @IBOutlet weak var displayFpsSwitch: UISwitch!
    @IBOutlet weak var displayShadows: UISwitch!
    @IBOutlet weak var wireframeSwitch: UISwitch!
    @IBOutlet weak var tileInfoSwitch: UISwitch!
    
    #if DEBUG
    fileprivate let showDebugControls = true
    #else
    fileprivate let showDebugControls = false
    #endif
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        let config = vc.gameConfig
        switch config.terrainStyle {
        case .satellite:
            terrainChooser.selectedSegmentIndex = 1
        case .mixed:
            terrainChooser.selectedSegmentIndex = 2
        default:
            terrainChooser.selectedSegmentIndex = 0
        }
        
        switch Preferences.preferedGear {
        case .runner:
            gearTypeChooser.selectedSegmentIndex = 0
        case .biker:
            gearTypeChooser.selectedSegmentIndex = 1
        }
        
        switch Preferences.preferedControllerSide {
        case .left:
            controllerSideSwitch.selectedSegmentIndex = 0
        case .right:
            controllerSideSwitch.selectedSegmentIndex = 1
        }
        
        showPopulationSwitch.isOn = Preferences.showPopulation
        playIntroSwitch.isOn = Preferences.showIntroMovie
        
        debugControlView.isHidden = !showDebugControls
        displayFpsSwitch.isOn = Globals.Config.displayFps
        displayShadows.isOn = Globals.Config.useShadows
        wireframeSwitch.isOn = config.showWireframe
        tileInfoSwitch.isOn = config.showDebugInfo
        
        let versionText = Platform.compileVersionString(includeBundleNumber: true, withBuildDate: true)
        self.versionLabel.text = versionText
    }
    
    @IBAction func terrainChanged(_ sender: UISegmentedControl)
    {
        var config = vc.gameConfig
        switch sender.selectedSegmentIndex {
        case 1:
            config.terrainStyle = .satellite
        case 2:
            config.terrainStyle = .mixed
        default:
            config.terrainStyle = .map
        }
        
        Preferences.preferedTerrain = config.terrainStyle
        vc.updateGameConfig(config, changed: .terrainStyle) { }
    }
    
    @IBAction func wireframeChanged(_ sender: UISwitch)
    {
        var config = vc.gameConfig
        config.showWireframe = sender.isOn
        vc.updateGameConfig(config, changed: .debugWirefame) { }
    }
    
    @IBAction func tileInfoChanged(_ sender: UISwitch)
    {
        var config = vc.gameConfig
        config.showDebugInfo = sender.isOn
        vc.updateGameConfig(config, changed: .debugInfo) { }
    }
    
    @IBAction func playIntro(_ sender: UISwitch)
    {
        Preferences.showIntroMovie = sender.isOn
    }
    
    @IBAction func controllerSideChanged(_ sender: UISegmentedControl)
    {
        Preferences.preferedControllerSide = sender.selectedSegmentIndex == 0 ? .left : .right
    }
    
    @IBAction func showPopulation(_ sender: UISwitch)
    {
        Preferences.showPopulation = sender.isOn
    }
    
    @IBAction func gearChanged(_ sender: UISegmentedControl)
    {
        Preferences.preferedGear = sender.selectedSegmentIndex == 0 ? .runner : .biker
    }
    
    @IBAction func displayFpsChanged(_ sender: UISwitch)
    {
        Globals.Config.displayFps = sender.isOn
    }
    
    @IBAction func displayShadowChanged(_ sender: UISwitch)
    {
        Globals.Config.useShadows = sender.isOn
    }
    
    @IBAction func toggleDebugView(_ sender: UITapGestureRecognizer)
    {
        debugControlView.isHidden = !debugControlView.isHidden
    }
    
    @IBAction func cleanStore(_ sender: UITapGestureRecognizer)
    {
        SecureStore.clean()
    }
}

class AboutViewController: BaseSettingsViewController
{
    @IBAction func goToN3xd(_ sender: Any)
    {
        if let url = URL(string: "https://www.n3xd.com") {
            UIApplication.shared.open(url)
        }
    }
}

class BaseSettingsViewController: UIViewController
{
    internal lazy var vc: ViewController = {
        guard
            let appDelegate = UIApplication.shared.delegate as? AppDelegate,
            let window = appDelegate.window,
            let vc = window.rootViewController as? ViewController
        else { fatalError("view controller not found") }
        return vc
    }()
}
