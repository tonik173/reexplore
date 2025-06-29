//
//  Terrain.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 17.06.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import MetalKit

class Terrain: Node
{
    static let numOfPatches:Int32 = 5
    static let terrainSizeXY = 2
    let patches = (horizontal: Int(numOfPatches), vertical: Int(numOfPatches))
    var patchCount: Int { return patches.horizontal * patches.vertical }
    var terrainInfo = TerrainInfo(size: [Float(terrainSizeXY), Float(terrainSizeXY)],
                                  height: 1.0,
                                  maxTessellation: UInt32(Renderer.maxTessellation),
                                  patches: [numOfPatches, numOfPatches])
    
    lazy var tessellationFactorsBuffer: MTLBuffer? = {
        let count = patchCount * (4 + 2)                    // 4 edge, 2 inside
        let size = count * MemoryLayout<Float>.size / 2     // tesselerator uses half-floats
        return Renderer.device.makeBuffer(length: size, options: .storageModePrivate)
    }()
    var controlPointsBuffer: MTLBuffer?
    var tessellationPipelineState: MTLComputePipelineState
    var renderPipelineState: MTLRenderPipelineState
    var y: Float = 1.0;
    var yBuffer: MTLBuffer?
    
    var heightMap0: MTLTexture?
    var heightMap1: MTLTexture?
    var heightMap2: MTLTexture?
    var heightMap3: MTLTexture?
    var heightMap4: MTLTexture?
    var heightMap5: MTLTexture?
    var heightMap6: MTLTexture?
    var heightMap7: MTLTexture?
    var heightMap8: MTLTexture?
    var satellite0: MTLTexture?
    
    var satellite1: MTLTexture?
    var satellite2: MTLTexture?
    var satellite3: MTLTexture?
    var satellite4: MTLTexture?
    var satellite5: MTLTexture?
    var satellite6: MTLTexture?
    var satellite7: MTLTexture?
    var satellite8: MTLTexture?
    
    var heightInfo: MTLTexture?
    var texturesLoaded = false;

    
    init(heightmapName: String, terrainTextureName: String, bounds: Float)
    {
        let controlPoints = Terrain.createControlPoints(patches: patches, size: (terrainInfo.size.x, terrainInfo.size.y))
        controlPointsBuffer = Renderer.device.makeBuffer(bytes: controlPoints, length: MemoryLayout<float3>.stride * controlPoints.count)
        yBuffer = Renderer.device.makeBuffer(bytes: &y, length: 4, options: .storageModeShared)
        
        tessellationPipelineState = Terrain.buildComputePipelineState()
        renderPipelineState = Terrain.buildRenderPipelineState()
        
        super.init()
        self.loadTextures() { self.texturesLoaded = true }

   /*

        do {
            let r = ImageHelpers.color(fromTexture: heightInfo, at: CGPoint(x: 25, y: 25))
            let vr = (Float(r.red)/256 + Float(r.green)/256 + Float(r.blue)/256)/2
            print("red: r:\(r.red), g:\(r.green), b:\(r.blue), a:\(r.alpha) -> \(vr)");
            
            let g = ImageHelpers.color(fromTexture: heightInfo, at: CGPoint(x: 75, y: 25))
            let vg = (Float(g.red)/256 + Float(g.green)/256 + Float(g.blue)/256)/2
            print("green r:\(g.red), g:\(g.green), b:\(g.blue), a:\(g.alpha) -> \(vg)");
            
            let b = ImageHelpers.color(fromTexture: heightInfo, at: CGPoint(x: 75, y: 75))
            let vb = (Float(b.red)/256 + Float(b.green)/256 + Float(b.blue)/256)/2
            print("blue r:\(b.red), g:\(b.green), b:\(b.blue), a:\(b.alpha) -> \(vb)");
            
            let y = ImageHelpers.color(fromTexture: heightInfo, at: CGPoint(x: 25, y: 75))
            let vy = (Float(y.red)/256 + Float(y.green)/256 + Float(y.blue)/256)/2
            print("yellow r:\(y.red), g:\(y.green), b:\(y.blue), a:\(y.alpha) -> \(vy)");
        }*/
    }
    
    func height(forPosition position: CGPoint) -> Float
    {
        if let heightInfo = self.heightInfo {
            let width = CGFloat(heightInfo.width)
            let height = CGFloat(heightInfo.height)
            
            let scaleX = width / CGFloat(terrainInfo.size.x)
            let x = width - (scaleX * position.x + scaleX * CGFloat(terrainInfo.size.x) / 2)

            let scaleY = height / CGFloat(terrainInfo.size.y)
            let y = (scaleY * position.y + scaleY * CGFloat(terrainInfo.size.y) / 2)
            
            let pt = CGPoint(x: x, y: y)
            _ = ImageHelpers.color(fromTexture: heightInfo, at: pt)
                
                
            //let mapboxHeight = (Float(color.red)/256.0 + Float(color.green)/256.0 + Float(color.blue)/256.0) / 2.0;
            //print("\(position.x)/\(position.y) ==> \(x)/\(y) :  \(mapboxHeight)")
            
            /*let summed: Int = Int(color.red) * 256 * 256 + Int(color.green) * 256 + Int(color.blue)
            let heightInMeter = -10000 + Float(summed) * 0.1
            let mapboxHeight = (heightInMeter - 400)/1500;
            print("\(position.x)/\(position.y) ==> \(x)/\(y) :  \(heightInMeter)m -> \(mapboxHeight)  | r:\(color.red), g:\(color.green), b:\(color.blue), a:\(color.alpha)")*/
            
        }
        return 0.0
    }
    
    fileprivate func loadTextures(doneHandler: @escaping SuccessHandler)
    {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                self.heightMap0 = try Terrain.loadTexture(forTile: Tile(x: 17154, y: 11509, zoom: 15), type: .gpuHeightmap)
                self.heightMap1 = try Terrain.loadTexture(forTile: Tile(x: 17155, y: 11509, zoom: 15), type: .gpuHeightmap)
                self.heightMap2 = try Terrain.loadTexture(forTile: Tile(x: 17156, y: 11509, zoom: 15), type: .gpuHeightmap)
                self.heightMap3 = try Terrain.loadTexture(forTile: Tile(x: 17154, y: 11510, zoom: 15), type: .gpuHeightmap)
                self.heightMap4 = try Terrain.loadTexture(forTile: Tile(x: 17155, y: 11510, zoom: 15), type: .gpuHeightmap)
                self.heightMap5 = try Terrain.loadTexture(forTile: Tile(x: 17156, y: 11510, zoom: 15), type: .gpuHeightmap)
                self.heightMap6 = try Terrain.loadTexture(forTile: Tile(x: 17154, y: 11511, zoom: 15), type: .gpuHeightmap)
                self.heightMap7 = try Terrain.loadTexture(forTile: Tile(x: 17155, y: 11511, zoom: 15), type: .gpuHeightmap)
                self.heightMap8 = try Terrain.loadTexture(forTile: Tile(x: 17156, y: 11511, zoom: 15), type: .gpuHeightmap)
                
                self.heightInfo = try Terrain.loadTexture(forTile: Tile(x: 17155, y: 11510, zoom: 15), type: .cpuHeightmap)
                
                self.satellite0 = try Terrain.loadTexture(forTile: Tile(x: 17154, y: 11509, zoom: 15), type: .satelliteImage)
                self.satellite1 = try Terrain.loadTexture(forTile: Tile(x: 17155, y: 11509, zoom: 15), type: .satelliteImage)
                self.satellite2 = try Terrain.loadTexture(forTile: Tile(x: 17156, y: 11509, zoom: 15), type: .satelliteImage)
                self.satellite3 = try Terrain.loadTexture(forTile: Tile(x: 17154, y: 11510, zoom: 15), type: .satelliteImage)
                self.satellite4 = try Terrain.loadTexture(forTile: Tile(x: 17155, y: 11510, zoom: 15), type: .satelliteImage)
                self.satellite5 = try Terrain.loadTexture(forTile: Tile(x: 17156, y: 11510, zoom: 15), type: .satelliteImage)
                self.satellite6 = try Terrain.loadTexture(forTile: Tile(x: 17154, y: 11511, zoom: 15), type: .satelliteImage)
                self.satellite7 = try Terrain.loadTexture(forTile: Tile(x: 17155, y: 11511, zoom: 15), type: .satelliteImage)
                self.satellite8 = try Terrain.loadTexture(forTile: Tile(x: 17156, y: 11511, zoom: 15), type: .satelliteImage)
                
                
                
                self.createMesh(from: self.heightMap4!)
            }
            catch let error as NSError {
                fatalError(error.localizedDescription)
            }
        }
        DispatchQueue.main.async {
            doneHandler()
        }
    }
    
    static func buildRenderPipelineState() -> MTLRenderPipelineState
    {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.depthAttachmentPixelFormat = .depth32Float
        descriptor.tessellationFactorStepFunction = .perPatch
        descriptor.maxTessellationFactor = Renderer.maxTessellation
        descriptor.tessellationPartitionMode = .fractionalEven
        
        guard let vertexFunction = Renderer.library?.makeFunction(name: "vertex_terrain") else {
            fatalError("vertex_terrain function not found")
        }
        descriptor.vertexFunction = vertexFunction
        
        guard let fragmentFunction = Renderer.library?.makeFunction(name: "fragment_terrain") else {
            fatalError("fragment_terrain function not found")
        }
        descriptor.fragmentFunction = fragmentFunction
        
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<float3>.stride
        vertexDescriptor.layouts[0].stepFunction = .perPatchControlPoint
        descriptor.vertexDescriptor = vertexDescriptor
        
        return try! Renderer.device.makeRenderPipelineState(descriptor: descriptor)
    }
    
    static func buildComputePipelineState() -> MTLComputePipelineState
    {
        guard let kernelFunction = Renderer.library?.makeFunction(name: "tessellation_terrain") else {
            fatalError("Tessellation shader function not found")
        }
        return try! Renderer.device.makeComputePipelineState(function: kernelFunction)
    }
    
    /**
         Loads texture tile for different usages
     */
    fileprivate static func loadTexture(forTile tile: Tile, type: TextureType) throws -> MTLTexture
    {
        let url = try type == .satelliteImage
            ? PathHelpers.satelliteImagesPath(forTile: tile)
            : PathHelpers.heightmapsPath(forTile: tile)
        print("loading texture \(url.path)")

        while !FileManager.default.fileExists(atPath: url.path) { sleep(1) }

        if type == .satelliteImage {
            return ImageHelpers.loadTexture(url: url, device: Renderer.device)!
        }
        else {
            let textureUsage = type == .cpuHeightmap
                ? MTLTextureUsage.pixelFormatView.rawValue
                : MTLTextureUsage.shaderRead.rawValue
            
            let options: [MTKTextureLoader.Option : Any] = [MTKTextureLoader.Option.SRGB: 0,
                                                            MTKTextureLoader.Option.allocateMipmaps: 0,
                                                            MTKTextureLoader.Option.textureUsage: textureUsage,
                                                            MTKTextureLoader.Option.origin: MTKTextureLoader.Origin.bottomLeft]
            
            let textureLoader = MTKTextureLoader(device: Renderer.device)
            return try textureLoader.newTexture(URL: url, options: options)
        }
    }
    
    /**
     Builds the terrain based on the height map
     **/
    func tesselate(commandBuffer: MTLCommandBuffer, uniforms: Uniforms)
    {
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { fatalError("makeComputeCommandEncoder failed"); }
        
        var cameraPosition = uniforms.viewMatrix.columns.3
        var terrainMatrix = modelMatrix
        
        computeEncoder.setComputePipelineState(tessellationPipelineState)
        computeEncoder.setBuffer(tessellationFactorsBuffer, offset: 0, index: 0)
        computeEncoder.setBytes(&cameraPosition, length: MemoryLayout<float4>.stride, index: 1)
        computeEncoder.setBytes(&terrainMatrix, length: MemoryLayout<float4x4>.stride, index: 2)
        computeEncoder.setBuffer(controlPointsBuffer, offset: 0, index: 3)
        computeEncoder.setBytes(&terrainInfo, length: MemoryLayout<TerrainInfo>.stride, index: 4)
        computeEncoder.setBuffer(yBuffer, offset: 0, index: 5)


        let width = min(patchCount, tessellationPipelineState.threadExecutionWidth)
        computeEncoder.dispatchThreadgroups(MTLSizeMake(patchCount, 1, 1), threadsPerThreadgroup: MTLSizeMake(width, 1, 1))
        computeEncoder.endEncoding()
    }
    
    func render(renderEncoder: MTLRenderCommandEncoder, uniforms: Uniforms)
    {
        var mvp = uniforms.projectionMatrix * uniforms.viewMatrix * self.worldTransform * self.modelMatrix
        
        renderEncoder.setRenderPipelineState(self.renderPipelineState)
        renderEncoder.setVertexBytes(&mvp, length: MemoryLayout<float4x4>.stride, index: 1)
        renderEncoder.setRenderPipelineState(self.renderPipelineState)
        renderEncoder.setVertexBuffer(self.controlPointsBuffer, offset: 0, index: 0)
        renderEncoder.setTriangleFillMode(self.fillMode)
        
        // heightmap
        if self.texturesLoaded {
            renderEncoder.setVertexTexture(self.heightMap0, index: 0)
            renderEncoder.setVertexTexture(self.heightMap1, index: 1)
            renderEncoder.setVertexTexture(self.heightMap2, index: 2)
            renderEncoder.setVertexTexture(self.heightMap3, index: 3)
            renderEncoder.setVertexTexture(self.heightMap4, index: 4)
            renderEncoder.setVertexTexture(self.heightMap5, index: 5)
            renderEncoder.setVertexTexture(self.heightMap6, index: 6)
            renderEncoder.setVertexTexture(self.heightMap7, index: 7)
            renderEncoder.setVertexTexture(self.heightMap8, index: 8)

            renderEncoder.setFragmentTexture(self.satellite0, index: 0)
            renderEncoder.setFragmentTexture(self.satellite1, index: 1)
            renderEncoder.setFragmentTexture(self.satellite2, index: 2)
            renderEncoder.setFragmentTexture(self.satellite3, index: 3)
            renderEncoder.setFragmentTexture(self.satellite4, index: 4)
            renderEncoder.setFragmentTexture(self.satellite5, index: 5)
            renderEncoder.setFragmentTexture(self.satellite6, index: 6)
            renderEncoder.setFragmentTexture(self.satellite7, index: 7)
            renderEncoder.setFragmentTexture(self.satellite8, index: 8)
        }
        
        renderEncoder.setVertexBytes(&self.terrainInfo, length: MemoryLayout<TerrainInfo>.stride, index: 6)

        // tesselation
        renderEncoder.setTessellationFactorBuffer(self.tessellationFactorsBuffer,offset: 0, instanceStride: 0)
        renderEncoder.drawPatches(numberOfPatchControlPoints: 4,
                                  patchStart: 0, patchCount: self.patchCount,
                                  patchIndexBuffer: nil,
                                  patchIndexBufferOffset: 0,
                                  instanceCount: 1, baseInstance: 0)
    }
    
    /**
     Create control points
     - Parameters:
     - patches: number of patches across and down
     - size: size of plane
     - Returns: an array of patch control points. Each group of four makes one patch.
     **/
    static func createControlPoints(patches: (horizontal: Int, vertical: Int),  size: (width: Float, height: Float)) -> [float3] {
        
        var points: [float3] = []
        // per patch width and height
        let width = 1 / Float(patches.horizontal)
        let height = 1 / Float(patches.vertical)
        
        for j in 0..<patches.vertical {
            let row = Float(j)
            for i in 0..<patches.horizontal {
                let column = Float(i)
                let left = width * column
                let bottom = height * row
                let right = width * column + width
                let top = height * row + height
                
                points.append([left, 0, top])
                points.append([right, 0, top])
                points.append([right, 0, bottom])
                points.append([left, 0, bottom])
            }
        }
        // size and convert to Metal coordinates
        // eg. 6 across would be -3 to + 3
        points = points.map {
            [$0.x * size.width - size.width / 2,
             0,
             $0.z * size.height - size.height / 2]
        }
        return points
    }
    
    fileprivate func createMesh(from heightmap: MTLTexture)
    {
        let STARTX: Float = -0.5
        let STARTZ: Float = -0.5
        let width = Int(heightmap.width)
        let height = Int(heightmap.height)
        let incx = Float(abs(-STARTX*2)) / Float(width - 1)
        let incz = Float(abs(-STARTZ*2)) / Float(height - 1)
        
        var positions: [Float] = []
        var textCoords: [Float] = []
        var indices: [UInt32] = []
        
        for row in 0..<height {
            for col in 0..<width {
                // position
                positions.append(STARTX + Float(col)*incx)
                let color = ImageHelpers.color(fromTexture: heightmap, atX: col, atY: row)
                let summed: Int = Int(color.red) * 256 * 256 + Int(color.green) * 256 + Int(color.blue)
                let heightInMeter = -10000 + Float(summed) * 0.1
                let y = heightInMeter * 1.0/1000.0
                positions.append(y)
                positions.append(STARTZ + Float(row)*incz)
                
                // texture coordinate
                textCoords.append(incx*Float(col)/Float(width))
                textCoords.append(incx*Float(row)/Float(height))
                
                // indices
                if col < width - 1 && row < height - 1 {
                    let leftTop = row * width + col;
                    let leftBottom = (row + 1) * width + col;
                    let rightBottom = (row + 1) * width + col + 1;
                    let rightTop = row * width + col + 1;

                    indices.append(UInt32(leftTop));
                    indices.append(UInt32(leftBottom));
                    indices.append(UInt32(rightTop));

                    indices.append(UInt32(rightTop));
                    indices.append(UInt32(leftBottom));
                    indices.append(UInt32(rightBottom));
                }
            }
        }
        
        _ = self.calcNormals(positions: positions, width: width, height: height)
  
        print("read")
    }
    
    fileprivate func createMesh(positions: [Float],
                                texCoords: [Float],
                                normals: [Float],
                                indices: [UInt32]) -> MTKMesh
    {
        let allocator = MTKMeshBufferAllocator(device: Renderer.device)

        let vertexBuffer = allocator.newBuffer(MemoryLayout<Float>.stride * positions.count, type: .vertex)
        let vertexMap = vertexBuffer.map()
        vertexMap.bytes.assumingMemoryBound(to: Float.self).assign(from: positions, count: positions.count)

        let indexBuffer = allocator.newBuffer(MemoryLayout<UInt32>.stride * indices.count, type: .index)
        let indexMap = indexBuffer.map()
        indexMap.bytes.assumingMemoryBound(to: UInt32.self).assign(from: indices, count: indices.count)

        let submesh = MDLSubmesh(indexBuffer: indexBuffer,
                                 indexCount: indices.count,
                                 indexType: .uInt16,
                                 geometryType: .triangles,
                                 material: nil)

        let vertexDescriptor = MDLVertexDescriptor()
        vertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
                                                            format: .float3,
                                                            offset: 0,
                                                            bufferIndex: 0)
        let mdlMesh = MDLMesh(vertexBuffer: vertexBuffer,
                              vertexCount: positions.count,
                              descriptor: vertexDescriptor,
                              submeshes: [submesh])

        let mesh = try? MTKMesh(mesh: mdlMesh, device: Renderer.device)
        return mesh!
    }
    
    fileprivate func exportWavefront(positions: [Float],
                                      texCoords: [Float],
                                      normals: [Float],
                                      indices: [UInt32])
    {
      let objfile = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("terrain.obj")
    
      do {
          if FileManager.default.fileExists(atPath: objfile.path) {
               try FileManager.default.removeItem(at: objfile)
          }
          
          try "o Terrain\n".write(to: objfile, atomically: true, encoding: String.Encoding.utf8)
          let filehandle = try FileHandle(forWritingTo: objfile)
          
          // positions
          var p = 0
          while p < positions.count {
              let str = "v \(positions[p]) \(positions[p+1]) \(positions[p+2])\n"
              if let data = str.data(using: String.Encoding.utf8) { filehandle.write(data) }
              p = p + 3
          }
          
          // texture coords
          var t = 0
          while t < texCoords.count {
              let str = "vt \(texCoords[t]) \(texCoords[t+1])\n"
              if let data = str.data(using: String.Encoding.utf8) { filehandle.write(data) }
              t = t + 2
          }
          
          // normals
          var n = 0
          while n < normals.count {
              let str = "vn \(normals[n]) \(normals[n+1]) \(normals[n+2])\n"
              if let data = str.data(using: String.Encoding.utf8) { filehandle.write(data) }
              n = n + 3
          }
          
          // indices
          var i = 0
          while i < indices.count {
              let str1 = "f \(indices[i]+1) \(indices[i+1]+1) \(indices[i+2]+1)\n"
              if let data = str1.data(using: String.Encoding.utf8) { filehandle.write(data) }
              let str2 = "f \(indices[i+3]+1) \(indices[i+4]+1) \(indices[i+5]+1)\n"
              if let data = str2.data(using: String.Encoding.utf8) { filehandle.write(data) }
              i = i + 6
          }
          
          filehandle.closeFile()
       } catch {
          // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
      }
    }
    
    fileprivate func calcNormals(positions: [Float], width: Int, height: Int) -> [Float]
    {
        var normals: [Float] = []
    
        for row in 0..<height {
            for col in 0..<width {
                var normal:SIMD3<Float> = vector3(0.0, 0.0, 0.0)
                if row > 0 && row < height - 1 && col > 0 && col < width - 1 {
                    let i0 = row * width * 3 + col * 3;
                    let v0 = vector3(positions[i0], positions[i0+1], positions[i0+2])

                    let i1 = row * width * 3 + (col - 1) * 3
                    let v1 = vector3(positions[i1], positions[i1+1], positions[i1+2]) - v0

                    let i2 = (row + 1) * width * 3 + col * 3
                    let v2 = vector3(positions[i2], positions[i2+1], positions[i2+2]) - v0

                    let i3 = row * width * 3 + (col + 1) * 3
                    let v3 = vector3(positions[i3], positions[i3+1], positions[i3+2]) - v0
                    
                    let i4 = (row - 1) * width * 3 + col * 3
                    let v4 = vector3(positions[i4], positions[i4+1], positions[i4+2]) - v0

                    let v12 = normalize(cross(v1, v2))
                    let v23 = normalize(cross(v2, v3))
                    let v34 = normalize(cross(v3, v4))
                    let v41 = normalize(cross(v4, v1))
                    normal = normalize(v12 + v23 + v34 + v41)
                }
                normal = normalize(normal)
                normals.append(normal.x)
                normals.append(normal.y)
                normals.append(normal.z)
            }
        }
        return normals
    }
}
