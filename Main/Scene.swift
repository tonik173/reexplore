//
//  Scene.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 16.06.2020.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import Foundation
import CoreGraphics

struct MeasureInfo
{
    var fps: Int = 0
}

protocol SceneNotificationDelegate : AnyObject
{
    func setHeight(meterAboveSeeLevel masl: Int)
    func setLocation(info: LocationInfo)
    func setLoadingProgress(inPercent progressInPercent: Int)
    func setInstrumentsInfo(info: MeasureInfo)
    func reloadElevationView(locations: [LocationInfo])
}

struct TileVariant : CustomStringConvertible, Equatable, Hashable
{
    static func == (lhs: TileVariant, rhs: TileVariant) -> Bool {
        return lhs.tile == rhs.tile                 // don't check for detail level
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.tile)                   // don't check for detail level
    }
    
    var description: String { String(describing: "\(self.tile)-\(self.detailLevel)") }

    var tile: Tile
    var detailLevel: UInt8          // 0 highest

    init(tile: Tile, detailLevel: UInt8 = 0)
    {
        self.tile = tile
        self.detailLevel = detailLevel
    }
}

class Scene: InputDeviceDelegate, CustomStringConvertible
{
    var description: String {
        var nodeCount = 0
        var renderInfoCount = 0
        var vertexCount = 0
        self.terrain.forEach { (terrainTile) in
            nodeCount += terrainTile.children.count
            terrainTile.children.forEach { (node) in
                if let model = node as? Model {
                    vertexCount += model.vertexCount
                }
            }
            renderInfoCount += terrainTile.renderInfos.count
            if let renderInfo = terrainTile.renderInfoForLevelInUse() {
                vertexCount += renderInfo.vertices.count
            }
            nodeCount += 1
        }
        
        for model in self.population.models {
            vertexCount += model.vertexCount
            nodeCount += 1
        }
        
        for node in self.renderables {
            if let model = node as? Model {
                vertexCount += model.vertexCount
            }
            nodeCount += 1
        }
        
        return "Scene loaded \(nodeCount) nodes, \(renderInfoCount) renderInfos, \(vertexCount) vertices."
    }
    
    func moveEvent(delta: float3, location: float2)
    {
        // Log.gui("move \(location.x)/\(location.y) with delta: \(delta.x)/\(delta.y)/\(delta.z)")
    }
    
    weak var sceneNotificationDelegate: SceneNotificationDelegate?
    
    let inputController = InputController()
    let physicsController = PhysicsController()
    var skybox: Skybox!
    var terrain: [TerrainTile] = []
    var initialTile: Tile?
    var gameConfig: GameConfig
    
    var sceneSize: CGSize
    
    let firstPersonCamera = FirstPersonCamera()
    let orthoCamera = OrthographicCamera()
    
    let rootNode = Node()
    var renderables: [Renderable] = []
    var allNodes: [Node] = []
    var population = Population()

    fileprivate var firstPersonUniforms = Uniforms()
    fileprivate var firstPersonFragmentUniforms = FragmentUniforms()
    fileprivate var orthoUniforms = Uniforms()
    fileprivate var orthoFragmentUniforms = FragmentUniforms()
    
    fileprivate var aligning = false
    
    fileprivate let geocoder: Geocoder
    
    var postProcessNodes: [PostProcess] { return allNodes.compactMap { $0 as? PostProcess } }
    
    init(sceneSize: CGSize, gameConfig: GameConfig)
    {
        self.sceneSize = sceneSize
        self.gameConfig = gameConfig
        self.geocoder = Geocoder()
        self.setupScene()
        self.sceneSizeWillChange(to: sceneSize)
        self.inputController.inputDeviceDelegate = self
    }
    
    var mainGear: GearModel? {
        return self.renderables.first { (renderable) -> Bool in
            renderable is GearModel
        } as? GearModel
    }
    
    func setupScene()
    {
        // override this to add objects to the scene
    }
    
    func updateGameConfig(_ gameConfig: GameConfig, changed: GameConfig.ChangedProperty, doneHandler: @escaping SuccessHandler)
    {
        // needs to be calculated before the new config is copied
        let cameraHeightChange = gameConfig.aboveGround - self.gameConfig.aboveGround
        self.gameConfig = gameConfig
        
        DispatchQueue.global(qos: .userInitiated).async {
            
            if changed == .gpxFileUrl {
                if let gpxFileUrl = gameConfig.gpxFileUrl {
                    let gpxParser = GPXFileParser(withUrl: gpxFileUrl)
                    if let location = gpxParser.getFirstWaypoint() {
                        self.gameConfig.location = location
                    }
                }
            }
            
            for terrainTile in self.terrain {
                terrainTile.updateGameConfig(self.gameConfig, changed: changed)
            }
            
            if changed == .location || changed == .gpxFileUrl {
                self.resetScene()
                Preferences.lastUsedLocation = self.gameConfig.location
            }
            else if changed == .cameraType {
                self.updateCamera(type: self.gameConfig.cameraType)
            }
            else if changed == .aboveGround
            {
                self.updateCameraHeight(delta: cameraHeightChange)
            }
            else if changed == .showPopulation
            {
                if (gameConfig.showPopulation) {
                    // in case we turn population on, we need to load the population models
                    // if we turn it off, we don't do anythings. Population models will be removed, once the tile gets out of view
                    self.resetScene()
                }
            }
            
            DispatchQueue.main.async {
                doneHandler()
            }
        }
    }
    
    func updateCamera(type: CameraType)
    {
    }
    
    func updateCameraHeight(delta: Float)
    {
    }
    
    func camera(forType type: CameraType) -> Camera
    {
        switch type {
        case .firstPerson:
            return self.firstPersonCamera
        case .orthograhic:
            return self.orthoCamera
        }
    }
    
    func resetScene()
    {
        if let delegate = self.sceneNotificationDelegate {
            delegate.reloadElevationView(locations: [LocationInfo]())
        }
        self.population.reset()
        self.terrain = [TerrainTile]()
    }
    
    // ------------------------------------------------------------------------------------------------------
    // MARK: - Uploaded track
    // ------------------------------------------------------------------------------------------------------

    fileprivate func populateUploadTrack(_ track: Track, inTerrainTile terrainTile: TerrainTile)
    {
        let trackTile = track.trackTile(forTile: terrainTile.tile)
        terrainTile.uploadTrack = trackTile?.texture
    }
    
    var uploadTrack: Track? {
        didSet {
            if let track = self.uploadTrack {
                for terrainTile in self.terrain {
                    self.populateUploadTrack(track, inTerrainTile: terrainTile)
                }
            }
        }
    }
    
    func loadUploadTrack()
    {
        if let url = self.gameConfig.gpxFileUrl {
            let gpxParser = GPXFileParser(withUrl: url)
            if let track = gpxParser.getTileCoords() {
                track.renderTrackTiles(device: Renderer.device)
                self.uploadTrack = track
            }
        }
    }
    
    // ------------------------------------------------------------------------------------------------------
    // MARK: - Track recorder
    // ------------------------------------------------------------------------------------------------------

    var trackRecorder: TrackRecorder? = .none
    fileprivate var segmentIndex = 0
    fileprivate var pointsInSegment = 0
    
    func startRecordingTrack()
    {
        let recorder = TrackRecorder()
        recorder.start(name: "Recording")
        self.trackRecorder = recorder
        self.startNewTrackSegment(initial: true)
    }
    
    func stopRecordingTrack() -> String?
    {
        self.segmentIndex = 0
        self.pointsInSegment = 0
        self.updateGameConfig(self.gameConfig, changed: .recording) {}
        self.notifySegmentInfo()

        var xml: String?
        if let recorder = self.trackRecorder {
            recorder.stop() { gpx in
                xml = gpx
            }
        }
        
        // don't display recorded track anymore
        for terrainTile in self.terrain {
            terrainTile.recordTrack = .none
        }
        
        self.trackRecorder = .none
        
        return xml
    }
    
    func record(location: GeoLocation, meterAboveSeeLevel masl: Float, forTile tile: Tile, atPosition position: float3)
    {
        if let recorder = self.trackRecorder {
            let playerPosition = float2(x: position.x, y: position.z)
            recorder.append(location: location, meterAboveSeeLevel: masl, forTile: tile, atPosition: playerPosition)
            for terrainTile in self.terrain {
                terrainTile.recordTrack = recorder.trackTexture(forTile: terrainTile.tile)
                
                if self.pointsInSegment > 1 {
                    self.notifySegmentInfo()
                }
            }
            self.pointsInSegment += 1
        }
    }
    
    func startNewTrackSegment(initial: Bool = false)
    {
        if self.pointsInSegment > 0 || initial {
            self.segmentIndex += 1
            self.pointsInSegment = 0
            self.updateGameConfig(self.gameConfig, changed: .recording) {}
            self.notifySegmentInfo()
            
            if let recorder = self.trackRecorder {
                recorder.incrementSegment()
            }
            
            Log.gui("segment: \(self.segmentIndex)")
        }
    }
    
    func backToTrackSegmentStart()
    {
        Log.gui("segment: pt in segment = \(self.pointsInSegment)")
        let isPartial = self.pointsInSegment > 1
        var changed = false
        if isPartial {
            changed = true
        }
        else if self.segmentIndex > 1 {
            self.segmentIndex -= 1
            changed = true
        }
        
        if changed {
            self.pointsInSegment = 0
            self.updateGameConfig(self.gameConfig, changed: .recording) {}
            self.notifySegmentInfo()
            
            if let recorder = self.trackRecorder {
                if let lastLocation = recorder.decrementSegment(isPartial: isPartial) {
                    Log.gui("segment: \(self.segmentIndex), jumping back to \(lastLocation.lat)/\(lastLocation.lon)")
                    self.gameConfig.location = lastLocation
                    self.updateGameConfig(self.gameConfig, changed: .location) { }
                    
                    if let delegate = self.sceneNotificationDelegate {
                        let route = recorder.getRoute()
                        delegate.reloadElevationView(locations: route)
                    }
                }
            }
            
            Log.gui("segment: \(self.segmentIndex)")
        }
    }
    
    fileprivate func numberOfTrackSegments() -> String
    {
        if self.pointsInSegment > 1 {
            return "\(self.segmentIndex)*"
        }
        return "\(self.segmentIndex)"
    }
    
    fileprivate func notifySegmentInfo()
    {
        let payload = Notifications.payload(forSegmentIndex: self.numberOfTrackSegments())
        NotificationCenter.default.post(name: Notifications.updateSegment, object: nil, userInfo: payload)
    }
    
    // ------------------------------------------------------------------------------------------------------
    // MARK: - Player
    // ------------------------------------------------------------------------------------------------------
    
    /**
     Player position has been updated
     */
    private func updatePlayer(deltaTime: Float)
    {
        if let player = inputController.player {
            let holdPosition = player.position
            let holdRotation = player.rotation
            let controlInfo = self.inputController.updatePlayer(deltaTime: deltaTime)
            let playerGroundPosition  = float2(x: player.position.x, y: player.position.z)
            // Log.engine("updatePlayer \(player.position.x)/\(player.position.z) at \(player.position.y)")
            
            if controlInfo.direction.isZero && player.position.y > 0 {
                // we have no movement and the players height is initialized
                self.playerUpdated(player: player)
                self.updateAnimation(speed: 0)
                self.centerOrthoCameraView(toPosition: playerGroundPosition)
                return
            }
            
            // collision detection
            if physicsController.checkCollisions() && !updateCollidedPlayer() {
                player.position = holdPosition
                player.rotation = holdRotation
            }
            
            // player repositioning
            if let height = self.height(forPosition: playerGroundPosition) {
                player.position.y = height
                                
                if let delegate = self.sceneNotificationDelegate {
                    let masl = height / TerrainTile.scale / TerrainTile.yHeightScale
                    delegate.setHeight(meterAboveSeeLevel: Int(masl))
                    
                    if let terrainTile = self.terrainTile(forPosition: playerGroundPosition) {
                        let tile = TerrainTile.fractTileFor(position: player.position, tile: terrainTile.tile)
                        let info = self.geocoder.lookupLocation(position: player.position, meterAboveSeeLevel: masl, inTile: tile)
                        delegate.setLocation(info: info)
                        self.record(location: info.geoCord, meterAboveSeeLevel: masl, forTile: tile, atPosition: player.position)
                    }
                }
                // Log.engine("player.position: \(player.position.x) \t \(player.position.z) \t -> \(player.position.y)")
            }
            
            self.playerUpdated(player: player)
                        
            // reloads terrain tile according to the players position
            if controlInfo.didTranslateOrRotate() {
                self.updateTerrain(forPosition: playerGroundPosition)
            }
            
            // the ortho camera need to be relocated if the player moves
            if controlInfo.didTranslate {
                self.centerOrthoCameraView(toPosition: playerGroundPosition)
            }
            
            self.updateAnimation(speed: controlInfo.translationSpeed)
        }
    }
    
    func updateAnimation(speed: Float)
    {
    }
    
    func playerUpdated(player: Node)
    {
    }

    func relocateOrthoCameraView(by distance: float2)
    {
    }
    
    func centerOrthoCameraView(toPosition center: float2)
    {
    }
    
    func loadTerrainTiles()
    {
        if let location = self.gameConfig.location {
            let mercator = Mercator()
            self.initialTile = mercator.tile(longitude: location.lon, latitude: location.lat, zoom: Globals.Mapbox.zoom)
            self.releaseAndLoadTerrainTiles(withOffsetX: 0, withOffsetY: 0)
        }
    }
    
    /**
     offsetX and offsetY are tile indexes
     */
    fileprivate func releaseAndLoadTerrainTiles(withOffsetX offsetX: Int, withOffsetY offsetY: Int, direction: float2 = float2(repeating: 0))
    {
        if let initialTile = self.initialTile {
            // assembles a list of requred tiles
            var requiredTiles = Set<TileVariant>()
            let lowerX = direction.x < 0 ? -Int(TerrainTile.maxLevel) : -Int(TerrainTile.maxLevel - 1)
            let upperX = direction.x > 0 ? Int(TerrainTile.maxLevel) : Int(TerrainTile.maxLevel - 1)
            for x in lowerX...upperX {
                let lowerY = direction.y > 0 ? -Int(TerrainTile.maxLevel) : -Int(TerrainTile.maxLevel - 1)
                let upperY = direction.y < 0 ? Int(TerrainTile.maxLevel) : Int(TerrainTile.maxLevel - 1)
                for y in lowerY...upperY {
                    let tileX = initialTile.x + x + offsetX
                    let tileY = initialTile.y + y - offsetY
                    let tile = Tile(x: tileX, y: tileY, zoom: 15)
                    let detailLevel = UInt8(max(0, max(abs(x), abs(y))))
                    let tileVariant = TileVariant(tile: tile, detailLevel: detailLevel)
                    requiredTiles.insert(tileVariant)
                }
            }
            
            // assembles a list of required tiles, which already exist
            var existingAndRequiredTiles = Set<TileVariant>()
            for terrainTile in Array(self.terrain) { // loop over existing
                let tileVariant = requiredTiles.first(where: { (tileVariant) -> Bool in
                    tileVariant.tile == terrainTile.tile
                })
                
                if let tileVariant = tileVariant {
                    // we still need this tile
                    existingAndRequiredTiles.insert(TileVariant(tile: terrainTile.tile))
                    // update
                    terrainTile.detailLevelInUse = tileVariant.detailLevel
                }
                else {
                    // terrainTile is no longer required
                    self.terrain.removeAll {
                        let tbr = $0 == terrainTile
                        if tbr { print("terrainTile \(terrainTile) removed") }
                        return tbr
                    }
                    remove(node: terrainTile)
                }
            }
            
            // creates missing nodes
            let newTerrainTiles = requiredTiles.subtracting(existingAndRequiredTiles)
            let orderedNewTerrainTiles = newTerrainTiles.sorted { (tv1, tv2) -> Bool in
                tv1.detailLevel < tv2.detailLevel
            }
            orderedNewTerrainTiles.forEach { (tileVariant) in
                let terrainTile = TerrainTile(forTile: tileVariant.tile, requiredDetailLevel: tileVariant.detailLevel, withConfig: self.gameConfig, population: self.population)
                terrainTile.position.x = Float(tileVariant.tile.x - initialTile.x)*TerrainTile.scale*TerrainTile.sideLen
                terrainTile.position.z = Float(initialTile.y - tileVariant.tile.y)*TerrainTile.scale*TerrainTile.sideLen
                terrainTile.name = tileVariant.description
                add(node: terrainTile)
                self.terrain.append(terrainTile)
                if let track = self.uploadTrack {
                    self.populateUploadTrack(track, inTerrainTile: terrainTile)
                }
            }
        }
    }
    
    // loads one row/column more in the players view direction
    func updateTerrain(forPosition position: float2)
    {
        let halfTileLen = TerrainTile.halfSideLen*TerrainTile.scale
        let tileLen = 2*halfTileLen
        
        let xOffset = Int((position.x + sign(position.x) * halfTileLen) / tileLen)
        let yOffset = Int((position.y + sign(position.y) * halfTileLen) / tileLen)
        // Log.engine("xOffset: \(xOffset), yOffset: \(yOffset)")
        
        if let player = self.inputController.player {
            let rotateMatrix = float4x4(rotation: player.rotation)
            let driveVector = rotateMatrix * float4(0,0,1,0)
            let direction = float2(x: driveVector.x, y: driveVector.z)
            self.releaseAndLoadTerrainTiles(withOffsetX: xOffset, withOffsetY: yOffset, direction: direction)
        }
    }
    
    fileprivate func alignTerrainEdges()
    {
        // order by detail level, first is zero
        var terrainTiles = self.terrain
        terrainTiles.sort { (terrainTile1, terrainTile2) -> Bool in
            return terrainTile1.detailLevelInUse < terrainTile2.detailLevelInUse
        }
        
        for terrainTile in terrainTiles {
            let north = self.terrainTile(forTileX: terrainTile.tile.x, tileY:terrainTile.tile.y - 1)
            let south = self.terrainTile(forTileX: terrainTile.tile.x, tileY:terrainTile.tile.y + 1)
            let west = self.terrainTile(forTileX: terrainTile.tile.x - 1, tileY:terrainTile.tile.y)
            let east = self.terrainTile(forTileX: terrainTile.tile.x + 1, tileY:terrainTile.tile.y)
            terrainTile.alignBorders(north: north, south: south, west: west, east: east)
            
            if terrainTile.detailLevelInUse == 0 {
                let northWest = self.terrainTile(forTileX: terrainTile.tile.x - 1, tileY:terrainTile.tile.y - 1)
                terrainTile.alignCorners(horizontal: west, vertical: north, diagonal:northWest, compassPoint: .northWest)
            }
        }
    }
    
    fileprivate func alignTerrainCorners()
    {
        if let zero = terrainAtCenter() {
            let north = self.terrainTile(forTileX: zero.tile.x, tileY:zero.tile.y - 1)
            let south = self.terrainTile(forTileX: zero.tile.x, tileY:zero.tile.y + 1)
            let west = self.terrainTile(forTileX: zero.tile.x - 1, tileY:zero.tile.y)
            let east = self.terrainTile(forTileX: zero.tile.x + 1, tileY:zero.tile.y)
            let northWest = self.terrainTile(forTileX: zero.tile.x - 1, tileY:zero.tile.y - 1)
            let northEast = self.terrainTile(forTileX: zero.tile.x + 1, tileY:zero.tile.y - 1)
            let soutWest = self.terrainTile(forTileX: zero.tile.x - 1, tileY:zero.tile.y + 1)
            let southEast = self.terrainTile(forTileX: zero.tile.x + 1, tileY:zero.tile.y + 1)
            zero.alignCorners(horizontal: west, vertical: north, diagonal:northWest, compassPoint: .northWest)
            zero.alignCorners(horizontal: east, vertical: north, diagonal:northEast, compassPoint: .northEast)
            zero.alignCorners(horizontal: west, vertical: south, diagonal:soutWest, compassPoint: .southWest)
            zero.alignCorners(horizontal: east, vertical: south, diagonal:southEast, compassPoint: .southEast)
        }
    }
    
    fileprivate func terrainAtCenter() -> TerrainTile?
    {
        return self.terrain.first(where: { (terrainTile) -> Bool in terrainTile.detailLevelInUse == 0 })
    }
    
    func height(forPosition position: float2) -> Float?
    {
        if let terrainTile = self.terrainTile(forPosition: position) {
            return terrainTile.height(forPosition: position, useScale: true)
        }
        return .none
    }
    
    func updateCollidedPlayer() -> Bool
    {
        // override this
        return false
    }
    
    fileprivate var secondsExpired: Float = 0
    final func update(deltaTime: Float)
    {
        if Globals.Config.displayFps {
            self.secondsExpired += deltaTime
            if self.secondsExpired > 1 {
                self.secondsExpired = 0
                if let delegate = self.sceneNotificationDelegate {
                    let measureInfo = MeasureInfo(fps: Int(Instrument.averageFps))
                    delegate.setInstrumentsInfo(info: measureInfo)
                }
            }
        }
        
        updatePlayer(deltaTime: deltaTime)
        
        firstPersonUniforms.projectionMatrix = self.firstPersonCamera.projectionMatrix
        firstPersonUniforms.viewMatrix = self.firstPersonCamera.viewMatrix
        firstPersonFragmentUniforms.cameraPosition = self.firstPersonCamera.position
        
        orthoUniforms.projectionMatrix = self.orthoCamera.projectionMatrix
        orthoUniforms.viewMatrix = self.orthoCamera.viewMatrix
        orthoFragmentUniforms.cameraPosition = self.orthoCamera.position
        
        updateScene(deltaTime: deltaTime)
        update(nodes: rootNode.children, deltaTime: deltaTime)
    }
    
    final func uniformsFor(miniView: Bool) -> Uniforms
    {
        let mainIsFirstPersonCamera = self.gameConfig.cameraType == .firstPerson
        if miniView {
            return mainIsFirstPersonCamera ? self.orthoUniforms : self.firstPersonUniforms
        }
        else {
            return mainIsFirstPersonCamera ? self.firstPersonUniforms : self.orthoUniforms
        }
    }
    
    final func fragmentUniformsFor(miniView: Bool) -> FragmentUniforms
    {
        let mainIsFirstPersonCamera = self.gameConfig.cameraType == .firstPerson
        if miniView {
            return mainIsFirstPersonCamera ? self.orthoFragmentUniforms : self.firstPersonFragmentUniforms
        }
        else {
            return mainIsFirstPersonCamera ? self.firstPersonFragmentUniforms : self.orthoFragmentUniforms
        }
    }
    
    func needsRendering(isMiniView miniView: Bool, renderable: Renderable) -> Bool
    {
        if let _ = renderable as? GearModel {
            let mainIsFirstPersonCamera = self.gameConfig.cameraType == .firstPerson
            if miniView {
                return mainIsFirstPersonCamera ? false : true
            }
            else {
                return mainIsFirstPersonCamera ? true : false
            }
        }
        else if let _ = renderable as? BigGearModel {
            let mainIsFirstPersonCamera = self.gameConfig.cameraType == .firstPerson
            if miniView {
                return mainIsFirstPersonCamera ? true : false
            }
            else {
                return mainIsFirstPersonCamera ? false : true
            }
        }
        return true
    }
    
    private func update(nodes: [Node], deltaTime: Float)
    {
        nodes.forEach { node in
            node.update(deltaTime: deltaTime)
            update(nodes: node.children, deltaTime: deltaTime)
        }
    }
    
    fileprivate var prevLoadingProgressInPercent:Float = -1
    func updateScene(deltaTime: Float)
    {
        var totalLoadingProgressInPercent: Float = 0
        let terrainTiles = self.terrain
        for terrainTile in terrainTiles {
            terrainTile.update(deltaTime: deltaTime)
            totalLoadingProgressInPercent += terrainTile.loadingProgressInPercent()
        }

        totalLoadingProgressInPercent = max(0, min(100, ceil(totalLoadingProgressInPercent/Float(terrainTiles.count))))
        if prevLoadingProgressInPercent != totalLoadingProgressInPercent {
            prevLoadingProgressInPercent = totalLoadingProgressInPercent
            Log.load("\(self) Loading at \(totalLoadingProgressInPercent)%")
            sceneNotificationDelegate?.setLoadingProgress(inPercent: Int(totalLoadingProgressInPercent))
        }
        
        if !self.aligning {
            self.aligning = true
            DispatchQueue.global(qos: .utility).async {
                // two edges run, then one corner
                self.alignTerrainEdges()
                self.alignTerrainEdges()
                self.alignTerrainCorners()
                DispatchQueue.main.async {
                    self.aligning = false
                }
            }
        }
    }
    
    func terrainTile(forPosition position: float2) -> TerrainTile?
    {
        let offset = TerrainTile.halfSideLen*TerrainTile.scale
        for terrainTile in self.terrain {
            let terrainTilePosX = terrainTile.position.x
            if position.x > (terrainTilePosX - offset) && position.x < (terrainTilePosX + offset) {
                let terrainTilePosY = terrainTile.position.z
                if position.y > (terrainTilePosY - offset) && position.y < (terrainTilePosY + offset) {
                    //print("target tile: \(String(describing: terrainTile))")
                    return terrainTile
                }
            }
        }
        return .none
    }
    
    func terrainTile(forTileX tileX: Int, tileY: Int) -> TerrainTile?
    {
        let tile = Tile(x: tileX, y: tileY, zoom: Globals.Mapbox.zoom)
        for terrainTile in self.terrain {
            if terrainTile.tile == tile && terrainTile.fullyLoaded() {
                return terrainTile
            }
        }
        return .none
    }
    
    final func add(node: Node, parent: Node? = nil, render: Bool = true)
    {
        if let parent = parent {
            parent.add(childNode: node)
        } else {
            rootNode.add(childNode: node)
        }
        allNodes.append(node)
        guard render == true,
              let renderable = node as? Renderable
        else { return }
        
        renderables.append(renderable)
    }
    
    final func remove(node: Node)
    {
        if let parent = node.parent {
            parent.remove(childNode: node)
        } else {
            for child in node.children {
                child.parent = nil
            }
            node.children = []
        }
        guard let allNodesIndex = (allNodes.firstIndex {
            $0 === node
        }) else { return }
        allNodes.remove(at: allNodesIndex)
        
        guard node is Renderable,
              let index = (renderables.firstIndex {
                $0 as? Node === node
              }) else { return }
        renderables.remove(at: index)
    }
    
    func sceneSizeWillChange(to size: CGSize)
    {
        let ratio = Float(size.width / size.height)
        self.firstPersonCamera.aspect = ratio
        self.orthoCamera.aspect = ratio
        sceneSize = size
    }
}

