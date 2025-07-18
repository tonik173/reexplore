//
//  ViewController.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 16.06.2020.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import MetalKit

class ViewController: LocalViewController, SceneNotificationDelegate
{
    var renderer: Renderer?
    var miniRenderer: Renderer?
    var gameConfig: GameConfig = GameConfig()

    deinit
    {
        UserDefaults.standard.removeObserver(self, forKeyPath: Preferences.Keys.showPopulation)
    }

    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        UserDefaults.standard.addObserver(self, forKeyPath: Preferences.Keys.showPopulation, options: NSKeyValueObservingOptions.new, context: nil)
        
        guard let metalView = view as? MTKView else { fatalError("metal view not set up in storyboard") }
        metalView.preferredFramesPerSecond = 30
        renderer = Renderer(metalView: metalView)
        addGestureRecognizers(to: metalView)
                
        self.gameConfig.location = Preferences.lastUsedLocation
        if self.gameConfig.location == .none {
            self.gameConfig.location = GeoLocation(lat: 47.10589, lon: 8.47518) // Chiemen
            Preferences.lastUsedLocation = self.gameConfig.location
        }
        
        let scene = GameScene(withSceneSize: metalView.bounds.size, gameConfig: self.gameConfig)
        scene.sceneNotificationDelegate = self
        
        renderer?.scene = scene
        
        if Globals.Config.hasMiniView {
            if let miniMapView = self.miniMapView {
                miniMapView.preferredFramesPerSecond = 15
                miniRenderer = Renderer(metalView: miniMapView, isMiniView: true)
                miniRenderer?.scene = scene
            }
        }
        
        if let gameView = metalView as? GameView {
            gameView.inputController = scene.inputController
        }
        
        #if DEBUG
        SecureStore.clean()
        #endif
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?)
    {
        if keyPath == Preferences.Keys.showPopulation {
            var gameConfig = self.gameConfig
            gameConfig.showPopulation = Preferences.showPopulation
            self.updateGameConfig(gameConfig, changed: .showPopulation) { }
        }
    }
    
    func updateGameConfig(_ gameConfig: GameConfig, changed: GameConfig.ChangedProperty, doneHandler: @escaping SuccessHandler)
    {
        self.gameConfig = gameConfig
        if let renderer = self.renderer, let scene = renderer.scene {
            scene.updateGameConfig(gameConfig, changed: changed, doneHandler: doneHandler)
        }
    }
    
    func startRecordingTrack()
    {
        Log.gui("Recording started")
        if let scene = renderer?.scene {
            scene.startRecordingTrack()
        }
    }
    
    func stopRecordingTrack() -> String?
    {
        Log.gui("Recording stoped")
        if let scene = renderer?.scene {
            return scene.stopRecordingTrack()
        }
        return .none
    }
    
    func startNewTrackSegment()
    {
        if let scene = renderer?.scene {
            scene.startNewTrackSegment()
        }
    }
    
    func backToTrackSegmentStart()
    {
        if let scene = renderer?.scene {
            scene.backToTrackSegmentStart()
        }
    }
    
    override func setHeight(meterAboveSeeLevel masl: Int)
    {
        super.setHeight(meterAboveSeeLevel: masl)
    }
    
    override func setLocation(info: LocationInfo)
    {
        super.setLocation(info: info)
    }
    
    override func setLoadingProgress(inPercent progressInPercent: Int)
    {
        super.setLoadingProgress(inPercent: progressInPercent)
    }
    
    override func setInstrumentsInfo(info: MeasureInfo)
    {
        super.setInstrumentsInfo(info: info)
    }
    
    override func reloadElevationView(locations: [LocationInfo])
    {
        super.reloadElevationView(locations: locations)
    }
    
    #if os(macOS)
    func post(key: KeyboardControl, durationInSeconds duration: Double = -1)
    {
        if let inputController = self.renderer?.scene?.inputController {
            inputController.keysDown.insert(key)
            if duration >= 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    inputController.keysDown.remove(key)
                }
            }
        }
    }
    #endif
}
