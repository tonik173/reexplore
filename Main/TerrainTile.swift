//
//  TerrainTile.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 27.08.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import MetalKit
import CoreImage

struct Vertex {
    var position: float3
    let texCoord: float2
}

enum LoadState {
    case notStarted
    case heightMapLoading
    case heightMapLoaded
    case texturesLoading
    case texturesLoaded
    case finalizing
    case fullyLoaded
}

enum CardinalPoint: Int
{
    case north = 0
    case northEast = 1
    case east = 2
    case southEast = 3
    case south = 4
    case southWest = 5
    case west = 6
    case northWest = 7
    
    var opposite: CardinalPoint {
        switch self {
        case .north: return .south
        case .south: return .north
        case .west: return .east
        case .east: return .west
        case .northEast: return .southWest
        case .northWest: return .southEast
        case .southEast: return .northWest
        case .southWest: return .northEast
        }
    }
}

struct RenderInfo : Equatable, CustomStringConvertible
{
    static func == (lhs: RenderInfo, rhs: RenderInfo) -> Bool {
        return lhs.detailLevel == rhs.detailLevel
    }
    
    var description: String { String(describing: "\(self.detailLevel): \(self.vertices.count)") }
    
    init(detailLevel: UInt8)
    {
        self.detailLevel = detailLevel
        self.vertices = []
        self.indices = []
        self.borders = [ .north:[], .east:[], .south:[], .west:[] ]
        self.alignedTo = [:]
    }
    
    var vertices: [Vertex]
    var indices: [UInt32]
    var vertexBuffer: MTLBuffer?
    var indexBuffer: MTLBuffer?
    let detailLevel: UInt8          // 0 highest
    var alignedTo: [String:String]
    
    // orginal border vertexes, used for alignment of the neighbour tiles
    var borders: [CardinalPoint:[Vertex]]
    
    mutating func updateBorders()
    {
        let length = Int(sqrt(Double(vertices.count)))
        for row in 0..<length {
            for col in 0..<length {
                let index = row*length + col
                let vertex = self.vertices[index]
                // borders
                if row == 0 {
                    self.borders[.south]?.append(vertex)
                }
                if row == length - 1 {
                    self.borders[.north]?.append(vertex)
                }
                if col == 0 {
                    self.borders[.west]?.append(vertex)
                }
                if col == length - 1 {
                    self.borders[.east]?.append(vertex)
                }
            }
        }
    }
}

class TerrainTile: Node
{
    static func == (lhs: TerrainTile, rhs: TerrainTile) -> Bool {
        return lhs.tile == rhs.tile
    }
    
    override var description: String {
        var rit = ""
        self.renderInfos.forEach { (renderInfo) in
            if rit.count == 0 {
                rit = renderInfo.description
            }
            else {
                rit = "\(rit.description), \(renderInfo.description)"
            }
        }
        return "terrain \(String(describing: self.tile)) with level \(self.detailLevelInUse) in use. Renderinfo vertexes for level: \(rit)"
    }
    
    let tile: Tile
    var gameConfig: GameConfig
    
    var renderInfos = SynchronizedArray<RenderInfo>()
    var flatViewRenderInfo: RenderInfo?
    var heightMapLen: Int?
    var heightMap: MTLTexture?
    var streets: MTLTexture?
    var satellite: MTLTexture?
    var uploadTrack: MTLTexture? = .none
    var recordTrack: MTLTexture? = .none
    var emptyTexture: MTLTexture? = .none
    var info: [MTLTexture]                          // one for each level
    var blendedTexture: MTLTexture?
    
    var detailLevelInUse: UInt8
    var modelProxies = [ModelProxy]()
    var usedComplexities = [ModelComplexityType]()
    let population: Population
    
    fileprivate var state = LoadState.notStarted {
        didSet { /* Log.load("new state of \(self.tile) is \(self.state)") */ }
    }
    
    var cornersAligned: [CardinalPoint:Bool]!
    
    init(forTile tile: Tile, requiredDetailLevel: UInt8, withConfig config: GameConfig, population: Population)
    {
        self.tile = tile
        self.gameConfig = config
        self.detailLevelInUse = requiredDetailLevel
        self.info = []
        self.cornersAligned = [:]
        self.population = population

        super.init()
        
        self.scale = float3(repeating: TerrainTile.scale)
        self.position = float3(repeating: 0)
        
        MapboxItemsDownloader.shared().downloadItems(forTile: self.tile)
        
        self.loadInAppTextures()
        self.info = self.setDebugInfo(forTile: self.tile)
        self.fillMode = self.gameConfig.showWireframe ? .lines : .fill
    }
    
    fileprivate var secondsExpired: Float = 1 // fires immediately
    override func update(deltaTime: Float)
    {
        super.update(deltaTime: deltaTime)
        
        let rand = Float.random(in: 0.25..<0.5)
        self.secondsExpired += deltaTime
        let timeElapsedInS = Float(self.detailLevelInUse * self.detailLevelInUse)*rand + rand
        if self.secondsExpired > timeElapsedInS {
            self.secondsExpired = 0
            self.loadTerrain()
        }
    }
    
    func loadTerrain()
    {
        guard self.state != .fullyLoaded else { return }
        
        // self.detailLevelInUse may change during the execution of the threads of this function. Therefore, we need to grab it at this time.
        let detailLevelInUse = self.detailLevelInUse
        
        Log.load("About to load tile \(self.tile)")

        // loads height map and creates inital (required) height mesh
        if self.state == .notStarted {
            self.state = .heightMapLoading
            var state = self.state
            Log.load("Loading tile \(self.tile)")
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    // loads heightmap
                    let heightmapUrl = try PathHelpers.heightmapsPath(forTile: self.tile)
                    if let heightMap = try self.loadTexture(forURL: heightmapUrl, type: .gpuHeightmap) {
                        Log.load("Heightmap texture for tile \(self.tile) loaded")
                        DispatchQueue.main.async {
                            self.heightMap = heightMap
                        }
                        
                        // once the heightmap is loaded, the initial terrain mesh can be created
                        if let renderInfo = self.createTerrainMesh(withHeightMap: heightMap, forDetaiLevel: detailLevelInUse) {
                            let flatViewRenderInfo = self.createTerrainMesh(withHeightMap: heightMap, forDetaiLevel: TerrainTile.maxLevel, yDefault: 0)
                            DispatchQueue.main.async {
                                self.renderInfos.append(renderInfo)
                                self.flatViewRenderInfo = flatViewRenderInfo
                            }
                            
                            Log.load("Heightmap mesh for tile \(self.tile) with detaillevel \(detailLevelInUse) created")
                            state = .heightMapLoaded
                        }
                        else { Log.warn("Heightmap mesh for tile \(self.tile) with detaillevel \(detailLevelInUse) could not be created. Will try again.") }
                    }
                    else { Log.warn("Heightmap mesh for tile \(self.tile) with detaillevel \(detailLevelInUse) could not be loaded. Will try again.") }
                }
                catch  { Log.error(error.localizedDescription) }
                
                DispatchQueue.main.async {
                    self.state = state == .heightMapLoading ? .notStarted : state
                }
            }
        }
        
        // loads textures
        if self.state == .heightMapLoaded {
            self.state = .texturesLoading
            var state = self.state
            DispatchQueue.global(qos: .userInitiated).async {
                var modelProxies: [ModelProxy]?
                if self.loadTerrainTextures() {
                    if self.detailLevelInUse == 0 {
                        modelProxies = self.population.populate(terrainTile: self, withStreets: self.streets)
                        Log.load("Terrain population for tile \(self.tile) loaded")
                    }
                    Log.load("Terrain textures for tile \(self.tile) loaded")
                    state = .texturesLoaded
                }
                else { Log.warn("Terrain textures for tile \(self.tile) not loaded. Will try again.") }
                
                DispatchQueue.main.async {
                    if let modelProxies = modelProxies {
                        self.modelProxies.append(contentsOf: modelProxies)
                        let usedComplexity = self.modelComplexity(forLevel: detailLevelInUse)
                        self.usedComplexities.append(usedComplexity)
                    }
                    self.state = state == .texturesLoading ? .heightMapLoaded : state
                }
            }
        }
        
        // create all but initial height mesh
        if self.state == .texturesLoaded {
            self.state = .finalizing
            let currentRenderInfos = self.renderInfos
            guard let heightMap = self.heightMap else {
                Log.error("No heightmap???")
                return
            }
            DispatchQueue.global(qos: .utility).async {
                // creates the missing meshes
                var completelyLoaded = true
                for level: UInt8 in 0...TerrainTile.maxLevel {
                    let renderInfoMissing = (currentRenderInfos.first { (renderInfo) -> Bool in renderInfo.detailLevel == level }) == .none
                    if renderInfoMissing {
                        // once the heightmap is loaded, the initial terrain mesh can be created
                        if let renderInfo = self.createTerrainMesh(withHeightMap: heightMap, forDetaiLevel: level) {
                            DispatchQueue.main.sync {
                                self.renderInfos.append(renderInfo)
                            }
                            Log.load("Heightmap mesh for tile \(self.tile) with detaillevel \(level) created")
                        }
                        else {
                            Log.warn("Heightmap mesh for tile \(self.tile) with detaillevel \(detailLevelInUse) could not be created. Will try again.")
                            completelyLoaded = false
                        }
                    }
                    
                    // creates the missing models (so far we may just loaded the model of a certain complexity. We need also to load the others.)
                    for complexity in ModelComplexityType.allCases {
                        if !self.usedComplexities.contains(complexity) {
                            let modelProxies = self.population.populate(terrainTile: self, withStreets: self.streets)
                            Log.load("Terrain population for tile \(self.tile) loaded")
                            DispatchQueue.main.async {
                                self.modelProxies.append(contentsOf: modelProxies)
                                self.usedComplexities.append(complexity)
                            }
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    Log.load("Terrain for tile \(self.tile) completely loaded")
                    self.state = completelyLoaded ? .fullyLoaded : .texturesLoaded
                }
            }
        }
    }
    
    func fullyLoaded() -> Bool
    {
        return self.state == .fullyLoaded
    }
    
    func loadingProgressInPercent() -> Float
    {
        switch self.state {
        case .notStarted: return 0
        case .heightMapLoading: return 10
        case .heightMapLoaded: return 40
        case .texturesLoading: return 40
        case .texturesLoaded: return 75
        case .finalizing: return 75
        case .fullyLoaded: return 100
        }
    }
    
    fileprivate func validateTerrain()
    {
        if self.fullyLoaded() {
            if self.renderInfos.count < TerrainTile.maxLevel {
                Log.error("Inconsistent render infos for \(self.description)")
            }
            for level in 0...TerrainTile.maxLevel {
                let renderInfo = self.renderInfo(forLevel: level)
                if renderInfo == .none {
                    Log.error("Inconsistent render infos for \(self.description). Missing level \(level)")
                }
            }
        }
    }
    
    // heig calculation using baricentric formula
    func height(forPosition position: float2, useScale: Bool = false) -> Float?
    {
        if let heightMapRenderInfo = self.renderInfo(forLevel: 0),
           let heightMapLen = self.heightMapLen {
            let scale = useScale ? TerrainTile.scale : Float(1)
            
            let xy = TerrainTile.index(forPosition: position, len: heightMapLen, useScale: useScale)
            
            let index00 = max(min(xy.y*heightMapLen + xy.x, heightMapLen*heightMapLen - 1), 0)
            let index10 = max(min(xy.y*heightMapLen + xy.x + 1, heightMapLen*heightMapLen - 1), 0)
            let index01 = max(min((xy.y + 1)*heightMapLen + xy.x, heightMapLen*heightMapLen - 1), 0)
            let index11 = max(min((xy.y + 1)*heightMapLen + xy.x + 1, heightMapLen*heightMapLen - 1), 0)

            let coord = float2(x: Float(xy.x/heightMapLen), y: Float(xy.y/heightMapLen))
            
            var height: Float? = .none
            if xy.x <= 1 - xy.y {
                let yp1 = heightMapRenderInfo.vertices[index00].position.y*scale
                let p1 = float3(x: 0, y:yp1, z: 0)
                let yp2 = heightMapRenderInfo.vertices[index10].position.y*scale
                let p2 = float3(x: 1, y:yp2, z: 0)
                let yp3 = heightMapRenderInfo.vertices[index01].position.y*scale
                let p3 = float3(x: 0, y:yp3, z: 1)
                height = Math.barryCentric(p1: p1, p2: p2, p3: p3, position: coord)
            }
            else {
                let yp1 = heightMapRenderInfo.vertices[index10].position.y*scale
                let p1 = float3(x: 1, y:yp1, z: 0)
                let yp2 = heightMapRenderInfo.vertices[index11].position.y*scale
                let p2 = float3(x: 1, y:yp2, z: 1)
                let yp3 = heightMapRenderInfo.vertices[index01].position.y*scale
                let p3 = float3(x: 0, y:yp3, z: 1)
                height = Math.barryCentric(p1: p1, p2: p2, p3: p3, position: coord)
            }            
            return height
        }
        return .none
    }
    
    static func index(forPosition position: float2, len: Int, useScale: Bool = false) -> (x:Int, y:Int)
    {
        let scale = useScale ? TerrainTile.scale : Float(1)
        let u = (position.x/scale + TerrainTile.halfSideLen).truncatingRemainder(dividingBy: TerrainTile.sideLen)
        let ux = u < 0 ? TerrainTile.sideLen + u : u
        let x = Int(ux / TerrainTile.sideLen * Float(len))
        
        let v = (position.y/scale + TerrainTile.halfSideLen).truncatingRemainder(dividingBy: TerrainTile.sideLen)
        let vy = v < 0 ? TerrainTile.sideLen + v : v
        let y = Int(vy / TerrainTile.sideLen * Float(len))
        
        return (x:x, y:y)
    }
    
    fileprivate func createTerrainMesh(withHeightMap heightMap: MTLTexture, forDetaiLevel detailLevel: UInt8, yDefault: Float? = .none) -> RenderInfo?
    {
        var renderInfo = RenderInfo(detailLevel: detailLevel)
        
        let compression = self.compressionFor(level: detailLevel)
        let heightmapModel = self.createMesh(fromTexture: heightMap, compression: compression, yDefault: yDefault)
        renderInfo.vertices = heightmapModel.vertices
        renderInfo.indices = heightmapModel.indices
        
        // buffers for heightmap model
        let hmVertexLength = MemoryLayout<Vertex>.stride * renderInfo.vertices.count
        renderInfo.vertexBuffer = Renderer.device.makeBuffer(bytes: renderInfo.vertices, length: hmVertexLength, options: [])
        renderInfo.vertexBuffer?.label = "initial vertex buffer level \(detailLevel)"
        let hmIndexLength = MemoryLayout<UInt32>.stride * renderInfo.indices.count
        renderInfo.indexBuffer = Renderer.device.makeBuffer(bytes: renderInfo.indices, length: hmIndexLength, options: [])
        renderInfo.indexBuffer?.label = "index buffer level \(detailLevel)"
        
        renderInfo.updateBorders()
        return renderInfo
    }
    
    fileprivate func loadInAppTextures()
    {
        do {
            // empty placeholder texture
            let textureLoader = MTKTextureLoader(device: Renderer.device)
            self.emptyTexture = try textureLoader.newTexture(name: "empty", scaleFactor: 1.0, bundle: nil, options: nil)
        }
        catch let error as NSError {
            fatalError(error.localizedDescription)
        }
    }

    
    fileprivate func loadTerrainTextures() -> Bool
    {
        do {
            // streets
            let streetsUrl = try PathHelpers.streetsImagesPath(forTile: self.tile)
            self.streets = try self.loadTexture(forURL: streetsUrl, type: .image)
            Log.load("Street texture for tile \(self.tile) loaded")
            
            // satellite
            let satelliteUrl = try PathHelpers.satelliteImagesPath(forTile: self.tile)
            self.satellite = try self.loadTexture(forURL: satelliteUrl, type: .image)
            Log.load("Satellite texture for tile \(self.tile) loaded")
            
            // builds the final terrain texture
            self.blendedTexture = self.processTerrainTexture(satelliteUrl, streetsUrl)
        }
        catch let error as NSError {
            fatalError(error.localizedDescription)
        }
        if let _ = self.blendedTexture { return true } else { return false }
    }
    
    fileprivate func processTerrainTexture(_ satelliteUrl: URL, _ streetsUrl: URL) -> MTLTexture?
    {
        #if os(macOS)
        let scaleFactor:Float = 1
        #else
        let scaleFactor:Float = 1
        #endif
        
        var alphaSatellite: Float = 0.0
        var alphaStreets: Float = 0.0
        let filterSatellite: CustomFilter.Purpose = .none
        var filterStreet: CustomFilter.Purpose = .none          // set to terrain to show custom terrains
        switch self.gameConfig.terrainStyle {
        case .map:
            alphaStreets = 1.0
            break
        case .enhanced:
            alphaStreets = 1.0
            filterStreet = .terrain
            break
        case .mixed:
            alphaSatellite = 1.0
            alphaStreets = 0.5
            break
        case .satellite:
            alphaSatellite = 1.0
            break
        case .custom:
            alphaStreets = 1.0
            break
        }
        let blendedSources: [ImageHelpers.ImageSourceInfo] = [
            (url: satelliteUrl, scale: 2*scaleFactor, alpha: alphaSatellite, filter: filterSatellite),
            (url: streetsUrl, scale: 1*scaleFactor, alpha: alphaStreets, filter: filterStreet),
        ]
        return ImageHelpers.loadTexture(sources: blendedSources, device: Renderer.device)
    }
    
    override func updateGameConfig(_ gameConfig: GameConfig, changed: GameConfig.ChangedProperty)
    {
        super.updateGameConfig(gameConfig, changed: changed)
        
        let prevConfig = self.gameConfig
        self.gameConfig = gameConfig
        
        if changed == .debugInfo {
            self.info = self.setDebugInfo(forTile: self.tile)
        }
        else if changed == .terrainStyle {
            if prevConfig.terrainStyle != gameConfig.terrainStyle {
                do {
                    Log.gui("update terrain texture for tile \(self.tile)")
                    let satelliteUrl = try PathHelpers.satelliteImagesPath(forTile: self.tile)
                    let streetsUrl = try PathHelpers.streetsImagesPath(forTile: self.tile)
                    if let blended = self.processTerrainTexture(satelliteUrl, streetsUrl) {
                        self.blendedTexture = blended
                        Log.warn("Could not update terrain texture for tile \(self.tile)")
                    }
                }
                catch let error as NSError {
                    fatalError(error.localizedDescription)
                }
            }
        }
    }
    
    fileprivate func setDebugInfo(forTile tile: Tile) -> [MTLTexture]
    {
        if self.gameConfig.showDebugInfo {
            return InfoTile.render(device: Renderer.device, tile: tile, maxLevel: TerrainTile.maxLevel)
        }
        else {
            return []
        }
    }
    
    /**
     Loads texture tile for different usages
     */
    fileprivate func loadTexture(forURL url: URL, type: TextureType) throws -> MTLTexture?
    {
        Log.downloader("loading texture \(url.path)")
        
        let start = DispatchTime.now()
        while !FileManager.default.fileExists(atPath: url.path)  {
            let timeSeconds = (DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1000 / 1000 / 1000
            if timeSeconds > 15 {
                Log.warn("Could not load texture for \(url.path)")
                return .none
            }
            sleep(1) // sleeps a second
        }
        
        if type == .image {
            return ImageHelpers.loadTexture(url: url, device: Renderer.device)!
        }
        else {
            let options: [MTKTextureLoader.Option : Any] = [MTKTextureLoader.Option.SRGB: 0,
                                                            MTKTextureLoader.Option.allocateMipmaps: 0,
                                                            MTKTextureLoader.Option.textureUsage: MTLTextureUsage.shaderRead.rawValue,
                                                            MTKTextureLoader.Option.origin: MTKTextureLoader.Origin.bottomLeft]
            
            let textureLoader = MTKTextureLoader(device: Renderer.device)
            return try textureLoader.newTexture(URL: url, options: options)
        }
    }
}

// ------------------------------------------------------------------------------------------------------
// MARK: - Alignment
// ------------------------------------------------------------------------------------------------------
extension TerrainTile
{
    fileprivate func updateY(atIndex index: Int, y: Float, renderInfo: inout RenderInfo)
    {
        var vertex = renderInfo.vertices[index]
        vertex.position.y = y
        renderInfo.vertices.remove(at: index)
        renderInfo.vertices.insert(vertex, at: index)
    }
    
    fileprivate func assignEdge(ratio: Int, start: Int, stepSize: Int, compass: CardinalPoint, renderInfoNext: RenderInfo, renderInfoThis: inout RenderInfo)
    {
        let nextLevelLen = Int(sqrt(Double(renderInfoNext.vertices.count)))
        var index = start
        for indexNeighbour in 0..<nextLevelLen {
            guard let p1 = renderInfoNext.borders[compass.opposite]?[indexNeighbour].position else { return }
            
            if ratio == 1 {
                // we have the same compression level. Get the height of the neigbour and assign it to myself
                updateY(atIndex: index, y: p1.y, renderInfo: &renderInfoThis)
                index += stepSize
            }
            else {
                let indexPlusOne = min(indexNeighbour + 1, nextLevelLen - 1)
                guard let p2 = renderInfoNext.borders[compass.opposite]?[indexPlusOne].position else { return }
                
                if distance(p1, p2) < Float(epsilon) {
                    for _ in 0..<ratio {
                        updateY(atIndex: index, y: p1.y, renderInfo: &renderInfoThis)
                        index += stepSize
                    }
                }
                else {
                    let p0 = renderInfoThis.vertices[index].position
                    let d12 = distance(p1, p2)
                    let inc = d12/Float(ratio)
                    for c in 0..<ratio {
                        var y: Float = 0
                        if compass == .north || compass == .south {
                            let x = p0.x + Float(c)*inc
                            let m = (p2.y - p1.y)/(p2.x - p1.x)
                            y = m*(x - p1.x) + p1.y
                        }
                        else {
                            let z = p0.z + Float(c)*inc
                            let m = (p2.y - p1.y)/(p2.z - p1.z)
                            y = m*(z - p1.z) + p1.y
                        }
                        updateY(atIndex: index, y: y, renderInfo: &renderInfoThis)
                        index += stepSize
                    }
                }
            }
        }
    }
    
    fileprivate func updateVertexBuffer(forRenderInfo renderInfo: inout RenderInfo)
    {
        let hmVertexLength = MemoryLayout<Vertex>.stride * renderInfo.vertices.count
        renderInfo.vertexBuffer = Renderer.device.makeBuffer(bytes: renderInfo.vertices, length: hmVertexLength, options: [])
        renderInfo.vertexBuffer?.label = "aligned vertex buffer level \(renderInfo.detailLevel)"
        if let index = renderInfos.index(where: { (ri) -> Bool in ri == renderInfo }) {
            renderInfos[index] = renderInfo        // replace
        }
    }
    
    func alignBorders(north: TerrainTile?, south: TerrainTile?, west: TerrainTile?, east: TerrainTile?)
    {
        guard self.fullyLoaded() else { return }
        guard let heightMapLength = self.heightMapLen else { return }
        guard var renderInfo = self.renderInfoForLevelInUse() else { return }
        
        let uncompressedHeightmapLen = heightMapLength*Int(self.compressionFor(level: 0))
        let thisLevelCompresssion = Int(self.compressionFor(level: self.detailLevelInUse))
        let thisLevelLen = uncompressedHeightmapLen/thisLevelCompresssion
        
        var didAlign: UInt8 = 0
        
        // north
        if let north = north {
            let nextLevelCompresssion = Int(self.compressionFor(level: north.detailLevelInUse))
            let ratio = nextLevelCompresssion/thisLevelCompresssion
            
            if let renderInfoNorth = north.renderInfo(forLevel: north.detailLevelInUse),
               needsAlignment(toNeighbour: north) {
                // north edge is the bottom row of the vertex array (top/left of the array is index 0)
                let start = (thisLevelLen-1)*thisLevelLen
                self.assignEdge(ratio: ratio, start: start, stepSize: 1, compass: .north, renderInfoNext: renderInfoNorth, renderInfoThis: &renderInfo)
                renderInfo.alignedTo[north.tile.description] = levelString(level1: self.detailLevelInUse, level2: north.detailLevelInUse)
                Log.engine("aligned \(self.tile.description):\(self.detailLevelInUse) to \(north.tile.description):\(north.detailLevelInUse)")
                didAlign += 1
            }
        }
        
        // south
        if let south = south {
            let nextLevelCompresssion = Int(self.compressionFor(level: south.detailLevelInUse))
            let ratio = nextLevelCompresssion/thisLevelCompresssion
            
            if let renderInfoSouth = south.renderInfo(forLevel: south.detailLevelInUse),
               needsAlignment(toNeighbour: south) {
                // south edge is the top row of the vertex array (top/left of the array is index 0)
                self.assignEdge(ratio: ratio, start: 0, stepSize: 1, compass: .south, renderInfoNext: renderInfoSouth, renderInfoThis: &renderInfo)
                renderInfo.alignedTo[south.tile.description] = levelString(level1: self.detailLevelInUse, level2: south.detailLevelInUse)
                Log.engine("aligned \(self.tile.description):\(self.detailLevelInUse) to \(south.tile.description):\(south.detailLevelInUse)")
                didAlign += 1
            }
        }
        
        // west
        if let west = west {
            let nextLevelCompresssion = Int(self.compressionFor(level: west.detailLevelInUse))
            let ratio = nextLevelCompresssion/thisLevelCompresssion
            
            if let renderInfoWest = west.renderInfo(forLevel: west.detailLevelInUse),
               needsAlignment(toNeighbour: west) {
                // west edge is the first column of the vertex array (top/left of the array is index 0)
                self.assignEdge(ratio: ratio, start: 0, stepSize: thisLevelLen, compass: .west, renderInfoNext: renderInfoWest, renderInfoThis: &renderInfo)
                renderInfo.alignedTo[west.tile.description] = levelString(level1: self.detailLevelInUse, level2: west.detailLevelInUse)
                Log.engine("aligned \(self.tile.description):\(self.detailLevelInUse) to \(west.tile.description):\(west.detailLevelInUse)")
                didAlign += 1
            }
        }
        
        // east
        if let east = east {
            let nextLevelCompresssion = Int(self.compressionFor(level: east.detailLevelInUse))
            let ratio = nextLevelCompresssion/thisLevelCompresssion
            
            if let renderInfoEast = east.renderInfo(forLevel: east.detailLevelInUse),
               needsAlignment(toNeighbour: east) {
                // east edge is the last column of the vertex array (top/left of the array is index 0)
                self.assignEdge(ratio: ratio, start: thisLevelLen - 1, stepSize: thisLevelLen, compass: .east, renderInfoNext: renderInfoEast, renderInfoThis: &renderInfo)
                renderInfo.alignedTo[east.tile.description] = levelString(level1: self.detailLevelInUse, level2: east.detailLevelInUse)
                Log.engine("aligned \(self.tile.description):\(self.detailLevelInUse) to \(east.tile.description):\(east.detailLevelInUse)")
                didAlign += 1
          }
        }
        
        if didAlign > 0 {
            self.updateVertexBuffer(forRenderInfo: &renderInfo)
            Log.load("Neighbour tiles for tile \(self.tile) at level \(self.detailLevelInUse) aligned at \(didAlign) edges")
        }
    }
    
    fileprivate func levelString(level1: UInt8, level2: UInt8) -> String
    {
        return "\(level1).\(level2)"
    }
    
    /**
     if there is already an alignment to the neighbour with the correct level, don't align it again
     */
    fileprivate func needsAlignment(toNeighbour neighbourTerrainTile: TerrainTile) -> Bool
    {
        guard let renderInfo = self.renderInfoForLevelInUse() else { return false }
        guard let neighbourRenderInfo = neighbourTerrainTile.renderInfo(forLevel: neighbourTerrainTile.detailLevelInUse) else { return false }
        
        // alignment works from lower to higher levels
        guard self.detailLevelInUse <= neighbourRenderInfo.detailLevel else { return false }
        
        // checks both ways (from this to the neighbour and vice versa). This is required for neighbours with the same level.
        // Otherwise a would align to b and b to a, resulting in two different, not matching, alignments
            
        // relation from this (renderInfo) to neighbour
        if let neighbourLevel = renderInfo.alignedTo[neighbourTerrainTile.tile.description] {
            let requiredLevel = levelString(level1: renderInfo.detailLevel, level2: neighbourRenderInfo.detailLevel)
            if requiredLevel == neighbourLevel {
                return false
            }
        }
        
        // relation from neighbour to this (renderInfo)
        if let thisLevel = neighbourRenderInfo.alignedTo[self.tile.description] {
            let requiredLevel = levelString(level1: neighbourRenderInfo.detailLevel, level2: renderInfo.detailLevel)
            if requiredLevel == thisLevel {
                return false
            }
        }

        return true
    }
    
    fileprivate func updateCorners(horizontal: TerrainTile, renderInfoH: inout RenderInfo, iH: Int,
                                   vertical: TerrainTile, renderInfoV: inout RenderInfo, iV: Int,
                                   diagonal: TerrainTile, renderInfoD: inout RenderInfo, iD: Int,
                                   renderInfo: inout RenderInfo, i: Int)
    {
        let yH = renderInfoH.vertices[iH].position.y
        let yV = renderInfoV.vertices[iV].position.y
        let yD = renderInfoD.vertices[iD].position.y
        let y = renderInfo.vertices[i].position.y
        let yCommon = (yV + yH + yD + y)/4
        self.updateY(atIndex: i, y: yCommon, renderInfo: &renderInfo)
        self.updateVertexBuffer(forRenderInfo: &renderInfo)
        vertical.updateY(atIndex: iV, y: yCommon, renderInfo: &renderInfoV)
        vertical.updateVertexBuffer(forRenderInfo: &renderInfoV)
        horizontal.updateY(atIndex: iH, y: yCommon, renderInfo: &renderInfoH)
        horizontal.updateVertexBuffer(forRenderInfo: &renderInfoH)
        diagonal.updateY(atIndex: iD, y: yCommon, renderInfo: &renderInfoD)
        diagonal.updateVertexBuffer(forRenderInfo: &renderInfoD)
    }
    
    func alignCorners(horizontal: TerrainTile?, vertical: TerrainTile?, diagonal: TerrainTile?, compassPoint: CardinalPoint)
    {
        guard self.detailLevelInUse == 0 else { return }
        if let _ = self.cornersAligned[compassPoint] { return }
        
        guard let horizontal = horizontal else { return }
        guard let vertical = vertical else { return }
        guard let diagonal = diagonal else { return }

        guard var renderInfo = self.renderInfoForLevelInUse() else { return }
        guard var horizontalRenderInfo = horizontal.renderInfo(forLevel: 1) else { return }
        guard var verticalRenderInfo = vertical.renderInfo(forLevel: 1) else { return }
        guard var diagonalRenderInfo = diagonal.renderInfo(forLevel: 1) else { return }

        let thisLevelLen = Int(sqrt(Double(renderInfo.vertices.count)))
        let nextLevelLen = Int(sqrt(Double(diagonalRenderInfo.vertices.count)))
        
        // northwest
        if compassPoint == .northWest {
            let iV = 0
            let iH = nextLevelLen*nextLevelLen - 1
            let iD = nextLevelLen - 1
            let i = thisLevelLen*(thisLevelLen - 1)
            updateCorners(horizontal: horizontal, renderInfoH: &horizontalRenderInfo, iH: iH,
                          vertical: vertical, renderInfoV: &verticalRenderInfo, iV: iV,
                          diagonal: diagonal, renderInfoD: &diagonalRenderInfo, iD: iD,
                          renderInfo: &renderInfo, i: i)
        }
        
        // northeast
        if compassPoint == .northEast {
            let iV = nextLevelLen - 1
            let iH = nextLevelLen*(nextLevelLen - 1)
            let iD = 0
            let i = thisLevelLen*thisLevelLen - 1
            updateCorners(horizontal: horizontal, renderInfoH: &horizontalRenderInfo, iH: iH,
                          vertical: vertical, renderInfoV: &verticalRenderInfo, iV: iV,
                          diagonal: diagonal, renderInfoD: &diagonalRenderInfo, iD: iD,
                          renderInfo: &renderInfo, i: i)
        }
        
        // southwest
        if compassPoint == .southWest {
            let iV = nextLevelLen*(nextLevelLen - 1)
            let iH = nextLevelLen - 1
            let iD = nextLevelLen*nextLevelLen - 1
            let i = 0
            updateCorners(horizontal: horizontal, renderInfoH: &horizontalRenderInfo, iH: iH,
                          vertical: vertical, renderInfoV: &verticalRenderInfo, iV: iV,
                          diagonal: diagonal, renderInfoD: &diagonalRenderInfo, iD: iD,
                          renderInfo: &renderInfo, i: i)
        }
        
        // southeast
        if compassPoint == .southEast {
            let iV = nextLevelLen*nextLevelLen - 1
            let iH = 0
            let iD = nextLevelLen*(nextLevelLen - 1)
            let i = thisLevelLen - 1
            updateCorners(horizontal: horizontal, renderInfoH: &horizontalRenderInfo, iH: iH,
                          vertical: vertical, renderInfoV: &verticalRenderInfo, iV: iV,
                          diagonal: diagonal, renderInfoD: &diagonalRenderInfo, iD: iD,
                          renderInfo: &renderInfo, i: i)
        }
        
        self.cornersAligned[compassPoint] = true
    }
}

// ------------------------------------------------------------------------------------------------------
// MARK: - Render
// ------------------------------------------------------------------------------------------------------
extension TerrainTile
{
    fileprivate static func buildRenderPipelineState() -> MTLRenderPipelineState
    {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.depthAttachmentPixelFormat = .depth32Float
        
        guard let vertexFunction = Renderer.makeFunction(name: "vertex_terrainTile") else {
            fatalError("vertex_terrain function not found")
        }
        descriptor.vertexFunction = vertexFunction
        
        guard let fragmentFunction = Renderer.makeFunction(name: "fragment_terrainTile") else {
            fatalError("fragment_terrain function not found")
        }
        descriptor.fragmentFunction = fragmentFunction
        
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = MemoryLayout<float3>.stride
        vertexDescriptor.attributes[1].bufferIndex = 0
        
        vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
        
        descriptor.vertexDescriptor = vertexDescriptor
        
        return try! Renderer.device.makeRenderPipelineState(descriptor: descriptor)
    }
    
    fileprivate func renderInfo(forLevel level: UInt8, accurate: Bool = true) -> RenderInfo?
    {
        var finalRenderInfo: RenderInfo? = .none
        self.renderInfos.forEach { (renderInfo) in
            if renderInfo.detailLevel == level {
                // this is the detail level we asked for
                finalRenderInfo = renderInfo
            }
            else if !accurate && renderInfo.detailLevel > level {
                // the detail level we asked for hasn't been found yet. We may return one with lower detail information.
                if finalRenderInfo == .none {
                    // the detail level we asked for hasn't been found yet. We may return this one.
                    finalRenderInfo = renderInfo
                }
                else if finalRenderInfo!.detailLevel < renderInfo.detailLevel {
                    // the detail level we asked for hasn't been found yet, but we have found one with a better resolution
                    finalRenderInfo = renderInfo
                }
            }
        }
        
        return finalRenderInfo
    }
    
    func renderInfoForLevelInUse() -> RenderInfo?
    {
        return self.renderInfo(forLevel: self.detailLevelInUse)
    }
    
    fileprivate func renderInfoFor(miniView: Bool) -> RenderInfo?
    {
        var renderInfo: RenderInfo? = .none
        let mainIsFirstPersonCamera = self.gameConfig.cameraType == .firstPerson
        if miniView {
            // this is the mini view
            renderInfo = mainIsFirstPersonCamera
                ? self.flatViewRenderInfo         // displays the ortho view in the mini view
                : self.renderInfoForLevelInUse()  // displays the fp view in the mini view
        }
        else {
            // this is the screen view
            renderInfo = mainIsFirstPersonCamera
                ? self.renderInfoForLevelInUse()   // displays the fp view in the mini view
                : self.flatViewRenderInfo          // displays the ortho view in the mini view
            
//            if renderInfo == .none && self.detailLevelInUse < TerrainTile.maxLevel {
//                Log.engine("RenderInfo missing for level \(self.detailLevelInUse) on main screen")
//            }
        }
        return renderInfo
    }
    
    func render(renderEncoder: MTLRenderCommandEncoder, uniforms vertex: Uniforms, fragmentUniforms fragment: FragmentUniforms, isMiniView: Bool)
    {
        if let renderInfo = self.renderInfoFor(miniView: isMiniView),
           let vertexBuffer = renderInfo.vertexBuffer,
           let indexBuffer = renderInfo.indexBuffer {
            
            if self.detailLevelInUse == 0 {
                // if the player is under a tree, we wanna see the back face
                renderEncoder.setCullMode(.none)
            }
            renderEncoder.setRenderPipelineState(TerrainTile.renderPipelineState)
            renderEncoder.setTriangleFillMode(self.fillMode)
            
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            
            var uniforms = vertex
            uniforms.modelMatrix = worldTransform
            uniforms.normalMatrix = uniforms.modelMatrix.upperLeft
            renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: Int(BufferIndexUniforms.rawValue))
            
            // terrain texture
            if isMiniView {
                renderEncoder.setFragmentTexture(self.streets, index: Int(TerrainTexture.rawValue))
            }
            else {
                renderEncoder.setFragmentTexture(self.blendedTexture, index: Int(TerrainTexture.rawValue))
            }
            
            // upload track
            if self.gameConfig.showTrack, let uploadTrack = self.uploadTrack {
                renderEncoder.setFragmentTexture(uploadTrack, index: Int(UploadTrackTexture.rawValue))
            }
            else {
                renderEncoder.setFragmentTexture(self.emptyTexture, index: Int(UploadTrackTexture.rawValue))
            }
            
            // record track
            if let recordTrack = self.recordTrack {
                renderEncoder.setFragmentTexture(recordTrack, index: Int(RecordTrackTexture.rawValue))
            }
            else {
                renderEncoder.setFragmentTexture(emptyTexture, index: Int(RecordTrackTexture.rawValue))
            }
            
            // info
            if self.info.count > 0 {
                let texture = self.info[Int(self.detailLevelInUse)]
                renderEncoder.setFragmentTexture(texture, index: Int(InfoTexture.rawValue))
            }
            
            // draws terrain
            renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                indexCount: renderInfo.indices.count,
                                                indexType: .uint32,
                                                indexBuffer: indexBuffer,
                                                indexBufferOffset: 0)
            
            if self.detailLevelInUse == 0 {
                renderEncoder.setCullMode(Renderer.defaultCullMode)
            }
        }
    }
}

// ------------------------------------------------------------------------------------------------------
// MARK: - Mesh creation
// ------------------------------------------------------------------------------------------------------
extension TerrainTile
{
    fileprivate func createMesh(fromTexture heightmap: MTLTexture, compression level: UInt8 = 1, yDefault: Float? = .none) -> (vertices: [Vertex], indices: [UInt32])
    {
        let compression = Int(level)
        let heightmapLength = heightmap.width
        guard heightmapLength == heightmap.height else {
            fatalError("Quadratic heightmaps are accepted only. This is \(heightmap.width)/\(heightmap.height)")
        }
        
        let length = heightmapLength / Int(level)
        let stepSize = heightmapLength/length
        let inc = TerrainTile.sideLen / Float(length-1)
        
        var vertices: [Vertex] = []
        var indices: [UInt32] = []
        
        // the height is always calculated for the most accurate compression (used for level 0)
        if compression == compressionFor(level: 0) {
            self.heightMapLen = length
        }
        
        for row in 0..<length {
            for col in 0..<length {
                // position
                let x = TerrainTile.start + Float(col)*inc
                var y: Float
                if let yDefault = yDefault {
                    y = yDefault
                }
                else {
                    let xi = col * stepSize
                    let yi = row * stepSize
                    let color = ImageHelpers.color(fromTexture: heightmap, atX: xi, atY: yi)
                    let summed: Int = Int(color.blue) * 256 * 256 + Int(color.green) * 256 + Int(color.red)
                    let heightInMeter = -10000 + Float(summed) * 0.1
                    y = heightInMeter * TerrainTile.yHeightScale
                }
                let z = TerrainTile.start + Float(row)*inc;
                
                let u = inc*Float(col)/TerrainTile.sideLen
                let v = inc*Float(row)/TerrainTile.sideLen
                
                let vertex = Vertex(position: float3(x: x, y: y, z: z), texCoord: float2(x: u, y: v))
                vertices.append(vertex)
                
                // indices
                if col < length - 1 && row < length - 1 {
                    let leftTop = row * length + col;
                    let leftBottom = (row + 1) * length + col;
                    let rightBottom = (row + 1) * length + col + 1;
                    let rightTop = row * length + col + 1;
                    
                    indices.append(UInt32(leftTop));
                    indices.append(UInt32(leftBottom));
                    indices.append(UInt32(rightTop));
                    
                    indices.append(UInt32(rightTop));
                    indices.append(UInt32(leftBottom));
                    indices.append(UInt32(rightBottom));
                }
            }
        }
        
        Log.misc("terrain with \(vertices.count) vertices created.")
        //Wavefront.export(positions: positions, texCoords: textCoords, normals: normals, indices: indices)
        return (vertices: vertices, indices: indices)
    }
}

// ------------------------------------------------------------------------------------------------------
// MARK: - Helpers
// ------------------------------------------------------------------------------------------------------

extension TerrainTile
{
    static func fractTileFor(position: float3, tile: Tile) -> Tile
    {
        let scaledPos = position/TerrainTile.scale
        let deltaX = (scaledPos.x + TerrainTile.halfSideLen).truncatingRemainder(dividingBy: TerrainTile.sideLen)/TerrainTile.sideLen
        let xf = Double(tile.x) + Double(deltaX);
        let deltaY = (TerrainTile.sideLen - (TerrainTile.halfSideLen + scaledPos.z).truncatingRemainder(dividingBy: TerrainTile.sideLen))/TerrainTile.sideLen
        let yf = Double(tile.y) + Double(deltaY);
        return Tile(x: tile.x, y: tile.y, zoom: tile.zoom, xf: xf, yf: yf)
    }
}

// ------------------------------------------------------------------------------------------------------
// MARK: - Constants
// ------------------------------------------------------------------------------------------------------
extension TerrainTile
{
    static let start: Float = -1.0
    
    #if os(iOS)
    fileprivate static let tileEdge = 1
    #else
    fileprivate static let tileEdge = 2
    #endif
    
    static let halfSideLen: Float = abs(start)
    static let sideLen: Float = halfSideLen*2.0  // => 800m
    static let scale: Float = 100.0
    static let yHeightScale: Float = 1.0/400.0
    static let renderPipelineState = TerrainTile.buildRenderPipelineState()
    
    static let maxLevel: UInt8 = UInt8(tileEdge) + 1
    
    static var maxNumOfTiles: UInt8 {   // 1: (1+1)*(1+1) + 2*(1+1) + 1 = 4
        let side = (maxLevel + 1)       // 2: (2+1)*(2+1) + 2*(2+1) + 1 = 16
        return side*side + 2*side + 1   // 3: (3+1)*(3+1) + 2*(3+1) + 1 = 25
    }
    
    // this number has to be the square of the max models in the population class of a certain complexity level
    #if os(iOS)
    static var maxPopulationPerTile: Int {
        if Globals.Config.hasMaxPopulation { return 800 }
        else { return 10 }
    }
    #else
    static var maxPopulationPerTile: Int {
        if Globals.Config.hasMaxPopulation { return 1200 }
        else { return 10 }
    }
    #endif

    fileprivate func compressionFor(level: UInt8) -> UInt8
    {
        #if os(iOS)
        var compression: UInt8!
        switch level {
        case 0: compression = 2
        case 1: compression = 8
        case 2: compression = 32
        default: compression = 32
        }
        return compression
        #else
        var compression: UInt8!
        switch level {
        case 0: compression = 2
        case 1: compression = 2
        case 2: compression = 4
        default: compression = 16
        }
        return compression
        #endif
    }
    
    func modelComplexity(forLevel level: UInt8) -> ModelComplexityType
    {
        switch level {
        case 0: return .full
        case 1: return .full
        default: return .placeholder
        }
    }
}

// ------------------------------------------------------------------------------------------------------
// MARK: - End
// ------------------------------------------------------------------------------------------------------
