//
//  Renderer.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 16.06.2020.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import MetalKit
#if os(iOS)
import FirebasePerformance
#endif

class Renderer: NSObject
{
    static let defaultCullMode = MTLCullMode.back
    static var device: MTLDevice!
    static var commandQueue: MTLCommandQueue!
    static var libraryQueue: DispatchQueue!
    static var library: MTLLibrary!
    static var colorPixelFormat: MTLPixelFormat!
    static var fps: Int!
    static var commandBuffer: MTLCommandBuffer?
    
    let depthStencilState: MTLDepthStencilState
    let lighting = Lighting()
    var scene: Scene?
    let isMiniView: Bool
    
    var shadowTextureStatic: MTLTexture!
    let shadowRenderPassDescriptorStatic = MTLRenderPassDescriptor()
    var shadowTextureDynamic: MTLTexture!
    let shadowRenderPassDescriptorDynamic = MTLRenderPassDescriptor()
    var shadowPipelineState: MTLRenderPipelineState!
    let shadowMapTextureScale: CGFloat = 3
    var shadowCounter = 0
    var shadowMatrix = float4x4.identity()
    
    lazy var sunlight: Light = {
        var light = buildDefaultLight()
        light.position = [0, 0, 0]
        light.intensity = 0.8
        light.color = [1, 1, 1]
        return light
    }()
    
    #if os(iOS)
    var fpsTrace: Trace?
    #endif
    
    func buildDefaultLight() -> Light
    {
        var light = Light()
        light.position = [0, 0, 0]
        light.color = [1, 1, 1]
        light.intensity = 1
        light.attenuation = float3(1, 0, 0)
        light.type = Sunlight
        return light
    }
    
    init(metalView: MTKView, isMiniView: Bool = false)
    {
        guard
            let device = MTLCreateSystemDefaultDevice(),
            let commandQueue = device.makeCommandQueue()
            else { fatalError("GPU not available") }
        Renderer.device = device
        Renderer.commandQueue = commandQueue
        Renderer.libraryQueue = DispatchQueue(label: "libraryQueue", attributes: .concurrent)
        Renderer.library = device.makeDefaultLibrary()
        Renderer.colorPixelFormat = metalView.colorPixelFormat
        Renderer.fps = metalView.preferredFramesPerSecond
        
        self.isMiniView = isMiniView
        metalView.device = device
        metalView.depthStencilPixelFormat = .depth32Float
        metalView.framebufferOnly = false
        
        depthStencilState = Renderer.buildDepthStencilState()!
        
        super.init()
        metalView.clearColor = MTLClearColor(red: 230/255, green: 228/255, blue: 224/255, alpha: 1)
        
        metalView.delegate = self
        mtkView(metalView, drawableSizeWillChange: metalView.bounds.size)
        
        if Globals.Config.useShadows {
            let size = CGSize(width: metalView.drawableSize.height * shadowMapTextureScale,
                              height: metalView.drawableSize.height * shadowMapTextureScale)
            buildShadowTextureStatic(size: size)
            buildShadowTextureDynamic(size: size)
            buildShadowPipelineState()
        }
    }
    
    static func buildDepthStencilState() -> MTLDepthStencilState?
    {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .less
        descriptor.isDepthWriteEnabled = true
        return Renderer.device.makeDepthStencilState(descriptor: descriptor)
    }
    
    static func makeFunction(name: String, constantValues: MTLFunctionConstantValues) -> MTLFunction?
    {
        var function: MTLFunction?
        Renderer.libraryQueue.sync(flags: .barrier) {
            do {
                function = try Renderer.library?.makeFunction(name: name, constantValues: constantValues)
            }
            catch {
                fatalError("Metal function \(name) does not exist")
            }
        }
        return function
    }
    
    static func makeFunction(name: String) -> MTLFunction?
    {
        var function: MTLFunction?
        Renderer.libraryQueue.sync(flags: .barrier) {
            function = Renderer.library?.makeFunction(name: name)
        }
        return function
    }
    
    func buildTexture(pixelFormat: MTLPixelFormat, size: CGSize, label: String) -> MTLTexture
    {
        var newSize = size
        #if os(iOS)
        if Renderer.device.supportsFeatureSet(MTLFeatureSet.iOS_GPUFamily2_v2)  || Renderer.device.supportsFeatureSet(MTLFeatureSet.iOS_GPUFamily1_v2) {
            newSize = CGSize(width: min(size.width, 8192), height: min(size.height, 8192))
        }
        #endif
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat,
            width: Int(newSize.width), height: Int(newSize.height), mipmapped: false)
        descriptor.usage = [.shaderRead, .renderTarget]
        descriptor.storageMode = .private
        guard let texture = Renderer.device.makeTexture(descriptor: descriptor) else { fatalError() }
        texture.label = "\(label) texture"
        return texture
    }
    
    func buildShadowTextureStatic(size: CGSize)
    {
        shadowTextureStatic = buildTexture(pixelFormat: .depth16Unorm, size: size, label: "ShadowStatic")
        shadowRenderPassDescriptorStatic.setUpDepthAttachment(texture: shadowTextureStatic)
    }
    
    func buildShadowTextureDynamic(size: CGSize)
    {
        shadowTextureDynamic = buildTexture(pixelFormat: .depth16Unorm, size: size, label: "ShadowDynamic")
        shadowRenderPassDescriptorDynamic.setUpDepthAttachment(texture: shadowTextureDynamic)
    }
    
    func buildShadowPipelineState()
    {
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = Renderer.library.makeFunction(name: "vertex_depth")
        pipelineDescriptor.fragmentFunction = nil
        pipelineDescriptor.colorAttachments[0].pixelFormat = .invalid
        let vertexDescriptor = Model.vertexDescriptor
        pipelineDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(vertexDescriptor)
        pipelineDescriptor.depthAttachmentPixelFormat = .depth16Unorm
        do {
            shadowPipelineState = try Renderer.device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        }
        catch let error {
            fatalError(error.localizedDescription)
        }
    }
}

extension Renderer: MTKViewDelegate
{
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize)
    {
        scene?.sceneSizeWillChange(to: size)
        if !self.isMiniView && Globals.Config.useShadows {
            let size = CGSize(width: size.height * shadowMapTextureScale, height: size.height * shadowMapTextureScale)
            buildShadowTextureStatic(size: size)
            buildShadowTextureDynamic(size: size)
        }
    }
    
    fileprivate func updatePopulationInstanceBuffers(forShadow usedForShadow: Bool)
    {
        guard let scene = scene else { return }
        guard scene.gameConfig.renderTerrainPopulation(miniView: isMiniView) && Preferences.showPopulation else { return }
        var population = [ModelProxy]()
        for terrainTile in scene.terrain {
            if terrainTile.detailLevelInUse <= 1 || !usedForShadow {
                // get all the model proxies matching the current complexity level
                let modelProxies = terrainTile.modelProxies.filter({ (proxy) -> Bool in
                    proxy.complexity == terrainTile.modelComplexity(forLevel: terrainTile.detailLevelInUse)
                })
                population.append(contentsOf: modelProxies)
            }
        }
        
        // render population: at this time we have all the population models with the transforms
        // we need to update all the instance buffers, conatining the transforms
        if population.count > 0 {
            var models = [SimpleModel]()
            let orderedProxies = population.sorted { (mp1, mp2) -> Bool in mp1.name < mp2.name }
            var name = orderedProxies[0].name
            var model = scene.population.model(forName: name)!
            var instances = [Instances]()
            for index in 0..<orderedProxies.count {
                let proxy = orderedProxies[index]
                if name != proxy.name {
                    if index > 0 {
                        // the first model is done, create the instance buffer
                        model.updateBuffer(transforms: instances)
                    }
                    // fetch new model
                    name = proxy.name
                    model = scene.population.model(forName: name)!
                    models.append(model)
                    instances = [Instances]()
                }
                 
                instances.append(contentsOf: proxy.transforms)
            }
            // the last model is done
            model.updateBuffer(transforms: instances)
        }
    }
    
    func draw(in view: MTKView)
    {
        if !self.isMiniView && Globals.Config.displayFps {
            Instrument.calcFps()
        }
        
        #if os(iOS)
        self.fpsTrace = Performance.startTrace(name: "fps")
        #endif
        
        guard
            let scene = scene,
            let descriptor = view.currentRenderPassDescriptor,
            let commandBuffer = Renderer.commandQueue.makeCommandBuffer()
            else { return }
        
        var uniforms = scene.uniformsFor(miniView: self.isMiniView)
        let fragmentUniforms = scene.fragmentUniformsFor(miniView: self.isMiniView)
        let renderPopulation = scene.gameConfig.renderTerrainPopulation(miniView: isMiniView)
        let renderShadow = renderPopulation && Globals.Config.useShadows
        
        if renderShadow {
            if shadowCounter == 0 {
                guard let shadowEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: shadowRenderPassDescriptorStatic) else {  return }
                self.updatePopulationInstanceBuffers(forShadow: true)
                self.shadowMatrix = renderShadowPass(renderEncoder: shadowEncoder, uniforms: uniforms, models: scene.population.models)
            }
            shadowCounter += 1
            if shadowCounter == 20 { shadowCounter = 0 }
            uniforms.shadowMatrixStatic = shadowMatrix
        }
        
        if renderShadow {
            guard let shadowEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: shadowRenderPassDescriptorDynamic) else {  return }
            if let mainGear = scene.mainGear {
                uniforms.shadowMatrixDynamic = renderShadowPass(renderEncoder: shadowEncoder, uniforms: uniforms, models: [mainGear])
            }
        }

        
        if !self.isMiniView {
            // both views share the same scene, so it needs to be updated once only
            let deltaTime = 1 / Float(Renderer.fps)
            scene.update(deltaTime: deltaTime)
        }
           
        self.updatePopulationInstanceBuffers(forShadow: false)
        Renderer.commandBuffer = commandBuffer
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { fatalError("makeRenderCommandEncoder failed"); }
        renderEncoder.pushDebugGroup("Main pass")
        renderEncoder.label = "Main encoder"
        renderEncoder.setCullMode(Renderer.defaultCullMode)

        var lights = lighting.lights
        renderEncoder.setFragmentBytes(&lights, length: MemoryLayout<Light>.stride * lights.count, index: Int(BufferIndexLights.rawValue))
        
        scene.skybox?.update(renderEncoder: renderEncoder)
        scene.skybox?.render(renderEncoder: renderEncoder, uniforms: uniforms)
        
        for terrainTile in scene.terrain {
            if renderShadow {
                renderEncoder.setFragmentTexture(shadowTextureStatic, index: Int(ShadowStaticTexture.rawValue))
                renderEncoder.setFragmentTexture(shadowTextureDynamic, index: Int(ShadowDynamicTexture.rawValue))
            }
            terrainTile.render(renderEncoder: renderEncoder, uniforms: uniforms, fragmentUniforms: fragmentUniforms, isMiniView: self.isMiniView)
        }
        
        if renderPopulation {
            for model in scene.population.models {
                model.render(renderEncoder: renderEncoder, uniforms: uniforms, fragmentUniforms: fragmentUniforms)
            }
        }

        // render none-population models
        renderEncoder.setTriangleFillMode(.fill)
        for renderable in scene.renderables {
            if scene.needsRendering(isMiniView: self.isMiniView, renderable: renderable) {
                renderEncoder.pushDebugGroup(renderable.name)
                renderable.render(renderEncoder: renderEncoder, uniforms: uniforms, fragmentUniforms: fragmentUniforms)
                renderEncoder.popDebugGroup()
            }
        }
        
        renderEncoder.endEncoding()
       
        guard let drawable = view.currentDrawable else { return }
        scene.postProcessNodes.forEach { node in
            node.postProcess(inputTexture: drawable.texture)
        }
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        #if os(iOS)
        if let trace = self.fpsTrace {
            trace.stop()
            self.fpsTrace = .none
        }
        #endif
    }
    
    func renderShadowPass(renderEncoder: MTLRenderCommandEncoder, uniforms vertex: Uniforms, models: [Renderable]) -> float4x4
    {
        var uniforms = vertex
        
        renderEncoder.pushDebugGroup("Shadow pass")
        renderEncoder.label = "Shadow encoder"
        renderEncoder.setCullMode(.none)
        renderEncoder.setDepthStencilState(depthStencilState)
        renderEncoder.setDepthBias(0.01, slopeScale: 1.0, clamp: 0.01)
        
        let edge: Float = 150
        uniforms.projectionMatrix = float4x4(orthoLeft: -edge, right: edge, bottom: -edge, top: edge, near: 0.1, far: 400)
        let playerPosition = scene?.inputController.player?.position ?? [0, 0, 0]
        let sunPosition: float3 = [playerPosition.x + 50, playerPosition.y + 150, playerPosition.z - 75]
        let lookAt = float4x4(eye: sunPosition, center: playerPosition, up: [0, 1, 0])
        uniforms.viewMatrix = lookAt
        let shadowMatrix = uniforms.projectionMatrix * uniforms.viewMatrix
        
        renderEncoder.setRenderPipelineState(shadowPipelineState)
        for model in models {
            model.render(renderEncoder: renderEncoder, uniforms: uniforms)
        }
        renderEncoder.endEncoding()
        renderEncoder.popDebugGroup()
        
        return shadowMatrix
    }
}

private extension MTLRenderPassDescriptor
{
    func setUpDepthAttachment(texture: MTLTexture) {
        depthAttachment.texture = texture
        depthAttachment.loadAction = .clear
        depthAttachment.storeAction = .store
        depthAttachment.clearDepth = 1
    }
}

struct Instrument
{
    static fileprivate var fps: Double = 0
    static fileprivate var lastFrameStartTime: CFTimeInterval = 0
    static var averageFps: Double = 0
    static fileprivate var averageFpsCounter: Int = 0
    static fileprivate var averageFpsSum: Double = 0
 
    static func calcFps()
    {
        let thisFrameStartTime = CFAbsoluteTimeGetCurrent()
        let deltaTimeInSeconds = thisFrameStartTime - lastFrameStartTime
        fps = deltaTimeInSeconds == 0 ? 0 : 1/deltaTimeInSeconds

        averageFpsCounter += 1
        averageFpsSum += fps
        if averageFpsCounter >= 25 {
            averageFps = round(averageFpsSum/Double(averageFpsCounter))
            averageFpsCounter = 0
            averageFpsSum = 0
        }
        lastFrameStartTime = thisFrameStartTime;
    }
}
