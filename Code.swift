//
//  XXXX.swift
//  Reexplore
//
//  Created by Toni Kaufmann on XX.XX.2020.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//

2021-02-17 19:41:36.364142+0100 Reexplore[15823:1939107] 7.4.0 - [Firebase/Analytics][I-ACS023012] Analytics collection enabled
2021-02-17 19:41:36.364843+0100 Reexplore[15823:1939107] 7.4.0 - [Firebase/Analytics][I-ACS023220] Analytics screen reporting is enabled. Call +[FIRAnalytics logEventWithName:FIREventScreenView parameters:] to log a screen view event. To disable automatic screen reporting, set the flag FirebaseAutomaticScreenReportingEnabled to NO (boolean) in the Info.plist



forLatitude: 8.47518, longitude: 47.10589)
extension MTLTexture
{


    static func color(fromTexture texture: MTLTexture, at position: CGPoint) -> Color
    {
        let numOfComponents = 4
        let bytesPerPixel = numOfComponents * MemoryLayout<UInt8>.size
        var src = UnsafeMutableRawPointer.allocate(byteCount: bytesPerPixel, alignment: MemoryLayout<UInt8>.size)
        defer { src.deallocate() }
        var bind = src.assumingMemoryBound(to: UInt8.self)
        

        let x = Int(position.x)
        let y = Int(position.y)
        
        let region = MTLRegionMake2D(x, y, 1, 1)
        let bytesPerRow = texture.width * bytesPerPixel
        texture.getBytes(src, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        
        var components = [UInt8](repeating: 0, count: numOfComponents)
        for c in 0..<numOfComponents {
            components[c] = bind.pointee
            bind = bind.advanced(by: 1)
        }

        
        return Color(red: UInt8(255.0*components[0]), green: UInt8(255.0*components[1]), blue: UInt8(255.0*components[2]), alpha: 255)
    }
    
    #if os(iOS)
    typealias XImage = UIImage
    #elseif os(macOS)
    typealias XImage = NSImage
    #endif
    
    var cgImage: CGImage?
    {
        //assert(self.pixelFormat == .bgra8Unorm)
        
        // read texture as byte array
        let rowBytes = self.width * 4
        let length = rowBytes * self.height
        let bgraBytes = [UInt8](repeating: 0, count: length)
        let region = MTLRegionMake2D(0, 0, self.width, self.height)
        self.getBytes(UnsafeMutableRawPointer(mutating: bgraBytes), bytesPerRow: rowBytes, from: region, mipmapLevel: 0)
        
        // use Accelerate framework to convert from BGRA to RGBA
        var bgraBuffer = vImage_Buffer(data: UnsafeMutableRawPointer(mutating: bgraBytes),
                                       height: vImagePixelCount(self.height), width: vImagePixelCount(self.width), rowBytes: rowBytes)
        let rgbaBytes = [UInt8](repeating: 0, count: length)
        var rgbaBuffer = vImage_Buffer(data: UnsafeMutableRawPointer(mutating: rgbaBytes),
                                       height: vImagePixelCount(self.height), width: vImagePixelCount(self.width), rowBytes: rowBytes)
        let map: [UInt8] = [2, 1, 0, 3]
        vImagePermuteChannels_ARGB8888(&bgraBuffer, &rgbaBuffer, map, 0)
        
        // flipping image virtically
        let flippedBytes = bgraBytes // share the buffer
        var flippedBuffer = vImage_Buffer(data: UnsafeMutableRawPointer(mutating: flippedBytes),
                                          height: vImagePixelCount(self.height), width: vImagePixelCount(self.width), rowBytes: rowBytes)
        vImageVerticalReflect_ARGB8888(&rgbaBuffer, &flippedBuffer, 0)
        
        // create CGImage with RGBA
        let colorScape = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let data = CFDataCreate(nil, flippedBytes, length) else { return nil }
        guard let dataProvider = CGDataProvider(data: data) else { return nil }
        let cgImage = CGImage(width: self.width, height: self.height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: rowBytes,
                              space: colorScape, bitmapInfo: bitmapInfo, provider: dataProvider,
                              decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        return cgImage
    }
    
    var image: XImage? {
        guard let cgImage = self.cgImage else { return nil }
        #if os(iOS)
        return UIImage(cgImage: cgImage)
        #elseif os(macOS)
        return NSImage(cgImage: cgImage, size: CGSize(width: cgImage.width, height: cgImage.height))
        #endif
    }
}

extension MTLTexture {
    static func color(fromTexture texture: MTLTexture, at position: CGPoint) -> CGColor
    {
        //anythingHere2(texture)
        let numOfComponents = 4
        let bytesPerPixel = numOfComponents * MemoryLayout<Float>.size
        let bytesPerRow = texture.width * bytesPerPixel
        var src = UnsafeMutableRawPointer.allocate(byteCount: bytesPerPixel, alignment: MemoryLayout<Float>.size)
        defer { src.deallocate() }
        var bind = src.assumingMemoryBound(to: Float.self)
        
        for i in 0..<texture.width {
            for j in 0..<texture.height {
                
                let region = MTLRegionMake2D(i, j, 1, 1)
                texture.getBytes(src, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
                
                var components = [Float](repeating: 0, count: numOfComponents)
                for c in 0..<numOfComponents {
                    components[c] = bind.pointee
                    bind = bind.advanced(by: 1)
                }
                print("pixel \(i)/\(j): \(components[0]) / \(components[1]) / \(components[2]) / \(components[3]))")
            }
        }
        return CGColor(gray: 0.5, alpha: 1.0)
    }
    
    static func anythingHere2 (_ texture: MTLTexture)
    {
        let width = texture.width
        let height = texture.height
        let sourceRowBytes = width * MemoryLayout<Float>.size
        let floatValues = UnsafeMutableRawPointer.allocate(byteCount: width * height, alignment: MemoryLayout<Float>.size)
        
        defer {
            floatValues.deallocate()
        }
        texture.getBytes(floatValues, bytesPerRow: sourceRowBytes, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        var bind = floatValues.assumingMemoryBound(to: Float.self)
        
        for col in 0..<sourceRowBytes {
            for row in 0..<height {
                if bind.pointee != 0 {
                    print("\(col).\(row) = \(bind.pointee)")
                }
                bind = bind.advanced(by: 1)
            }
        }
        
        
        /* for i in 0..<sourceRowBytes * height {
         if bind.pointee != 0 {
         print("\(i/sourceRowBytes)=\(bind.pointee)")
         }
         bind = bind.advanced(by: 1)
         }*/
    }
    
    static func cgImage(fromTexture texture: MTLTexture) -> CGImage?
    {
        let bytesPerPixel = 4
        
        // The total number of bytes of the texture
        let imageByteCount = texture.width * texture.height * bytesPerPixel
        
        // The number of bytes for each image row
        let bytesPerRow = texture.width * bytesPerPixel
        
        // An empty buffer that will contain the image
        var src = [UInt8](repeating: 0, count: Int(imageByteCount))
        
        // Gets the bytes from the texture
        let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
        texture.getBytes(&src, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        
        // Creates an image context
        let bitmapInfo = CGBitmapInfo(rawValue: (CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
        let bitsPerComponent = 8
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: &src, width: texture.width, height: texture.height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)
        
        // Creates the image from the graphics context
        guard let dstImage = context?.makeImage() else { return nil }
        
        let image = NSImage(cgImage: dstImage, size: NSSize(width: texture.width, height: texture.height))
        
        return dstImage
    }
}


static func color(fromTextureName name: String, at position: CGPoint) -> Color
{
    let textureLoader = MTKTextureLoader(device: Renderer.device)
    do {
        let options: [MTKTextureLoader.Option : Any] = [MTKTextureLoader.Option.SRGB: 0,
                                                        MTKTextureLoader.Option.textureUsage: MTLTextureUsage.pixelFormatView.rawValue]
        let texture = try textureLoader.newTexture(name: name, scaleFactor: 1.0, bundle: Bundle.main, options: options)
    
        let color = ImageHelpers.color(fromTexture: texture, at: position)
        return color
    }
    catch {
        fatalError(error.localizedDescription)
    }
}

static func color2(fromTexture texture: MTLTexture, at position: CGPoint) -> Color
{
    let bytesPerRow = MemoryLayout<UInt8>.size * texture.width * 4
    let imageByteCount = texture.height * bytesPerRow
    if let imageBuffer = Renderer.device.makeBuffer( length: imageByteCount, options: .cpuCacheModeWriteCombined) {
        if let commandBuffer = Renderer.commandQueue.makeCommandBuffer() {
            if let blitEncoder = commandBuffer.makeBlitCommandEncoder() {
                
                blitEncoder.copy(from: texture,
                                 sourceSlice: 0,
                                 sourceLevel: 0,
                                 sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                                 sourceSize: MTLSize(width: texture.width, height: texture.height, depth: 1),
                                 to: imageBuffer,
                                 destinationOffset: 0,
                                 destinationBytesPerRow: bytesPerRow,
                                 destinationBytesPerImage: 0)
                
                blitEncoder.endEncoding()
                
                let buf = imageBuffer.contents()
                let ccc = buf
                
               /* var rawData   = [UInt8](repeating: 0, count: texture.width*texture.height*4)
                if texture.pixelFormat == .rgba8Uint {
                    for  i in 0..<rawData.count {
                                  var pixel = UInt8()
                                  let address =  UnsafePointer<UInt8>(imageBuffer.contents())+i
                                  memcpy(&pixel, address, sizeof(UInt8))
                                  rawData[i] = UInt8(pixel>>8)
                              }
                          }
                          else{
                              memcpy(&rawData, imageBuffer.contents(), imageBuffer.length)
                          }
                       
                          let cgprovider = CGDataProviderCreateWithData(nil, &rawData, imageByteCount, nil)*/
            }
            
        }
    }
    return Color(red: 0, green: 0, blue: 0, alpha: 0)
}


/*
[[patch(quad, 4)]] vertex VertexOut vertex_terrain(patch_control_point<ControlPoint> control_points [[stage_in]],
                                                   constant float4x4 &mvp [[buffer(1)]],
                                                   texture2d<float> heightMap [[texture(0)]],
                                                   constant TerrainInfo &terrainInfo [[buffer(6)]],
                                                   uint patchID [[patch_id]],
                                                   float2 patch_coord [[position_in_patch]])
{
    float u = patch_coord.x;
    float v = patch_coord.y;
    
    // mix: Returns the linear blend of x and y implemented as: x + (y – x) * a
    // a must be a value in the range 0.0 to 1.0. If a is not in the range 0.0 to 1.0, the return values are undefined.
    float2 top = mix(control_points[0].position.xz, control_points[1].position.xz, u);
    float2 bottom = mix(control_points[3].position.xz, control_points[2].position.xz, u);
    
    VertexOut out;
    float2 interpolated = mix(top, bottom, v);
    float4 position = float4(interpolated.x, 0.0, interpolated.y, 1.0);         // -terrain-bounds..terrain-bounds
    
    // heightmap
    float2 xy = (position.xz + terrainInfo.size / 2.0) / terrainInfo.size;
    constexpr sampler sample;
    float4 color = heightMap.sample(sample, xy);
    
    float r = color.r * 256, g = color.g * 256, b = color.b * 256;          // convert from 0..1 values to 0..255
    float heightInMeter = -10000 + (r * 256 * 256 + g * 256 + b) * 0.1;     // for Zug area, this is between 415 and 950 m
    
    const float heightMin = 380;
    const float heightMax = 1200;
    float heightRange = heightMax - heightMin;
    float scale = terrainInfo.height/heightRange;
    float mapboxHeight = (heightInMeter - heightMin) * scale;
    
    
    // rgb test image
    //float mapboxHeight = (color.r + color.g + color.b) / 2.0;
    
    float height = (mapboxHeight * 2 - 1) * terrainInfo.height;
    position.y = height;
    
    out.position  = mvp * float4(-position.x, position.yzw);
    out.color = float4(color.r, color.g, color.b, 1);
    out.uv = xy;
    
    return out;
}*/

/*fragment float4 fragment_terrain(VertexOut in [[stage_in]],
                                 texture2d<float> terrainTexture [[texture(1)]])
{
    //constexpr sampler sample(filter::linear, address::repeat);
    //float4 color = terrainTexture.sample(sample, in.uv)*10;
    return in.color;
    //return color;
}*/


fileprivate func createMesh(fromTexture heightmap: MTLTexture)
{
    let STARTX: Float = -0.5
    let STARTZ: Float = -0.5
    let width = Int(heightmap.width)
    let height = Int(heightmap.height)
    let incx = Float(abs(-STARTX*2)) / Float(width - 1)
    let incz = Float(abs(-STARTZ*2)) / Float(height - 1)
    
    var positions: [Float] = []
    //var textCoords: [Float] = []
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
            positions.append(1.0)
            
            // texture coordinate
            //textCoords.append(incx*Float(col)/Float(width))
            //textCoords.append(incx*Float(row)/Float(height))
            
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
    
    // let normals = self.calcNormals(positions: positions, width: width, height: height)
    
    print("ground mesh created")
    //self.exportWavefront(positions: positions, texCoords: textCoords, normals: normals, indices: indices)
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
                             indexType: .uint32,
                             geometryType: .triangles,
                             material: nil)
    
    let vertexDescriptor = MDLVertexDescriptor()
    vertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
                                                        format: .float4,
                                                        offset: 0,
                                                        bufferIndex: 0)
    let mdlMesh = MDLMesh(vertexBuffer: vertexBuffer,
                          vertexCount: positions.count,
                          descriptor: vertexDescriptor,
                          submeshes: [submesh])
    
    let mesh = try? MTKMesh(mesh: mdlMesh, device: Renderer.device)
    return mesh!
}

    static func cgImage2(fromURL url: URL) -> CGImage?
    {
        var pallette:[UInt8] = []
        for i in 0..<256 {
            pallette.append(UInt8(i))

        }
        
        let colorspace = CGColorSpace(indexedBaseSpace: CGColorSpaceCreateDeviceRGB(), last: 255, colorTable: pallette)!
        if let ciimage = CIImage(contentsOf: url, options: [CIImageOption.colorSpace: colorspace]) {
        
            let context = CIContext(options: nil)
            

            let image = context.createCGImage(ciimage, from: CGRect(x: 0, y: 0, width: 256, height: 256))
            
            
            return image
            

        }
        
/*        if let context = CGContext(data: nil,
                                 width: 256,
                                 height: 256,
                                 bitsPerComponent: 8,
                                 bytesPerRow: 256,
                                 space: colorspace,
                                 bitmapInfo: ) {
        }
        
        
        
        
        if let cgImage = convertCIImageToCGImage(inputImage: ciimage!)
        {
            if let context = CGContext(data: nil,
                                    width: cgImage.width,
                                    height: cgImage.height,
                                    bitsPerComponent: cgImage.bitsPerComponent,
                                    bytesPerRow: cgImage.bytesPerRow,
                                    space: cgImage.colorSpace!,
                                    bitmapInfo: cgImage.bitmapInfo.rawValue) {
                
                if let cgImage = context.createCGImage(inputImage, from: inputImage.extent) {
                      return cgImage
                  }
            
                let flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: CGFloat(cgImage.height))
                context.concatenate(flip)
                context.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))
            
                let cgImg = context.makeImage()
                return cgImg
            }
        }*/
        return .none
    }




if let cgImage = ImageHelpers.cgImage(fromURL: streetsUrl) {
    let filter = ColorBarrierFilter()
    filter.inputImage = CIImage(cgImage: cgImage)
    filter.minColor = CIVector(x: 215.0/256.0, y: 220.0/256.0, z: 190.0/256.0)
    filter.maxColor = CIVector(x: 230/256.0, y: 230/256.0, z: 210/256.0)
    if let output = filter.outputImage {
        if let final = ImageHelpers.cgImage(fromCIImage: output) {
            print(final)
        }
    }
}


fileprivate func alignEdges2()
{
    if isAligned != .notStarted {
        return
    }
    
    let level0count = Int(self.compressionFor(level: 1))/Int(self.compressionFor(level: 0))
    if level0count <= 1 {
        isAligned = .loaded
        return
    }
    
    isAligned = .loading
    
    if let heightMapLen = self.heightMapLen,
       var renderInfoZero = self.renderInfo(forLevel: 0),
       let renderInfoOne = self.renderInfo(forLevel: 1) {

        let level1len = Int(heightMapLen/level0count)
        
        // north
        do {
            var indexZero = (heightMapLen-1)*heightMapLen
            for x in 0..<level1len {
                let indexOne = (level1len-1)*level1len + x
                let y = renderInfoOne.vertices[indexOne].position.y
                let yNext = indexOne < level1len*level1len-1 ? renderInfoOne.vertices[indexOne+1].position.y : y
                let delta = yNext - y
                let inc = delta/Float(level0count)
                for c in 0..<level0count {
                    var vertex = renderInfoZero.vertices[indexZero]
                    vertex.position.y = y + Float(c)*inc - delta/3
                    renderInfoZero.vertices.remove(at: indexZero)
                    renderInfoZero.vertices.insert(vertex, at: indexZero)
                    indexZero += 1
                }
            }
        }
        
        // south
        do {
            var indexZero = 0
            for x in 0..<level1len {
                let indexOne = x
                let y = renderInfoOne.vertices[indexOne].position.y
                let yNext = indexOne < level1len*level1len-1 ? renderInfoOne.vertices[indexOne+1].position.y : y
                let delta = yNext - y
                let inc = delta/Float(level0count)
                for c in 0..<level0count {
                    var vertex = renderInfoZero.vertices[indexZero]
                    vertex.position.y = y + Float(c)*inc + delta/3
                    renderInfoZero.vertices.remove(at: indexZero)
                    renderInfoZero.vertices.insert(vertex, at: indexZero)
                    indexZero += 1
                }
            }
        }
        
        // west
        do {
            var indexZero = 0
            for z in 0..<level1len {
                let indexOne = z*level1len
                let y = renderInfoOne.vertices[indexOne].position.y
                let yNext = indexOne < level1len*(level1len-1) ? renderInfoOne.vertices[indexOne+level1len].position.y : y
                let delta = yNext - y
                let inc = delta/Float(level0count)
                for c in 0..<level0count {
                    var vertex = renderInfoZero.vertices[indexZero]
                    vertex.position.y = y + Float(c)*inc - delta/3
                    renderInfoZero.vertices.remove(at: indexZero)
                    renderInfoZero.vertices.insert(vertex, at: indexZero)
                    indexZero += heightMapLen
                }
            }
        }
        
        // east
        do {
            var indexZero = heightMapLen - 1
            for z in 0..<level1len {
                let indexOne = z*level1len + level1len - 1
                let y = renderInfoOne.vertices[indexOne].position.y
                let yNext = indexOne < level1len*(level1len-1) ? renderInfoOne.vertices[indexOne+level1len].position.y : y
                let delta = yNext - y
                let inc = delta/Float(level0count)
                for c in 0..<level0count {
                    var vertex = renderInfoZero.vertices[indexZero]
                    vertex.position.y = 1.0035*y + Float(c)*inc
                    renderInfoZero.vertices.remove(at: indexZero)
                    renderInfoZero.vertices.insert(vertex, at: indexZero)
                    indexZero += heightMapLen
                }
            }
        }
        
        let hmVertexLength = MemoryLayout<Vertex>.stride * renderInfoZero.vertices.count
        renderInfoZero.vertexBuffer = Renderer.device.makeBuffer(bytes: renderInfoZero.vertices, length: hmVertexLength, options: [])
        renderInfoZero.vertexBuffer?.label = "aligned vertex buffer level \(0)"
        
        // replace
        self.renderInfos.insert(renderInfoZero, at: 0)
        if let removeIndex = self.renderInfos.lastIndex(of: renderInfoZero) {
            self.renderInfos.remove(at: removeIndex)
        }
    }
    
    Log.load("Neighbour tiles for tile \(self.tile) aligned")
    isAligned = .loaded
}


fileprivate func allign(renderInfoZero: RenderInfo, startZero: Int, renderInfoOne: RenderInfo, startOne: Int, update:(_ index: Int, _ y: Float)->Void)
{
    if let heightMapLen = self.heightMapLen {
        let level0count = Int(self.compressionFor(level: 1))/Int(self.compressionFor(level: 0))
        let level1len = Int(heightMapLen/level0count)
        
        var indexZero = startZero
        for x in 0..<level1len {
            let indexOne = startOne + x
            let y = renderInfoOne.vertices[indexOne].position.y
            let yNext = indexOne < (level1len*level1len-1) ? renderInfoOne.vertices[indexOne+1].position.y : y
            let delta = yNext - y
            let inc = delta/Float(level0count)
            for c in 0..<level0count {
                let newY = y + Float(c)*inc - delta/3
                update(indexZero, newY)
                indexZero += 1
            }
        }
    }
}



struct Wallet: Decodable
{
    let gpxUploadsTotal: Int
}

fileprivate func getDocumentsDirectory() -> URL
{
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    let documentsDirectory = paths[0]
    return documentsDirectory
}

fileprivate func read() -> Wallet?
{
    let url = getDocumentsDirectory()
    
    do {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let wallet = try decoder.decode(Wallet.self, from: data)
        return wallet
    }
    catch {
        Log.error(error.localizedDescription)
    }
    return .none
}


let start = DispatchTime.now()

let end = DispatchTime.now()
let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds // <<<<< Difference in nano seconds (UInt64)
let timeInterval = Double(nanoTime) / 1_000_000_000 // Technically could overflow for long running tests
Log.model("Time to evaluate height \(height): \(timeInterval) seconds")

//            if (xCoord <= (1-zCoord)) {
//               answer = .barryCentric( p1:  Vector3f(0, heights[gridX][gridZ], 0),
//                                       p2:  Vector3f(1, heights[gridX + 1][gridZ], 0),
//                                       p3:  Vector3f(0, heights[gridX][gridZ + 1], 1),
//                                       pos: Vector2f(xCoord, zCoord));
//            } else {
//                answer = Maths
//                        .barryCentric( p1:  Vector3f(1, heights[gridX + 1][gridZ], 0),
//                                       p2:  Vector3f(1, heights[gridX + 1][gridZ + 1], 1),
//                                       p3:  Vector3f(0, heights[gridX][gridZ + 1], 1),
//                                       pos: Vector2f(xCoord, zCoord));
//            }

    
    func updateToolbar(hasDebugControls: Bool)
    {
        if hasDebugControls {
            let numOfItems = self.toolbar.items.count
            self.toolbar.insertItem(withItemIdentifier: NSToolbarItem.Identifier.debugInfo, at: numOfItems)
            self.toolbar.insertItem(withItemIdentifier: NSToolbarItem.Identifier.flexibleSpace, at: numOfItems)
        }
        else {
            if let index = self.toolbar.items.firstIndex(where: { (item) -> Bool in item.itemIdentifier == NSToolbarItem.Identifier.debugInfo }) {
                self.toolbar.removeItem(at: index)
                self.toolbar.removeItem(at: index)
           }
        }
    }
func height2(forPosition position: float2, useScale: Bool = false) -> Float?
{
    
    if let heightMapRenderInfo = self.renderInfo(forLevel: 0),
       let heightMapLen = self.heightMapLen {
        let scale = useScale ? TerrainTile.scale : Float(1)
        let xy = TerrainTile.index(forPosition: position, len: heightMapLen, useScale: useScale)
        let index = max(min(xy.y*heightMapLen + xy.x, heightMapLen*heightMapLen - 1), 0)
        // Log.engine("p: \(position.x)/\(position.y) \(xy.x)/\(xy.y) = index: \(index) -> \(heightMapRenderInfo.vertices[index].position.y) | (level: \(self.detailLevelInUse))")
        let height = heightMapRenderInfo.vertices[index].position.y*scale
        return height
    }
    return .none
}

    fileprivate func interpolateHeight(forPosition position:float2, inDirection direction: float2) -> Float?
    {
        //return self.height(forPosition: position)
        var height: Float? = .none
        if let startHeight = self.height(forPosition: position),
           let terrainTile = self.terrainTile(forPosition: position),
           let heightMapLen = terrainTile.heightMapLen {
            
            if direction.isZero {
                return startHeight
            }

            let poligonDistance = TerrainTile.sideLen / Float(heightMapLen - 1)
            let maxStepsPerPolygon = max(1, Int(floor(length(direction) / poligonDistance) - 1))
            
            // advances in the same direction until the height changes or we reach a certain number of steps
            var nextHeight:Float = startHeight
            var curPosition: float2 = float2(repeating: 0.0)
            var inc = 0
            while inc < 2*maxStepsPerPolygon && startHeight == nextHeight {
                inc = inc + 1
                curPosition = position + direction*Float(inc)
                if let height = self.height(forPosition: curPosition) {
                    nextHeight = height
                }
            }
            
            // advances to the next poligon and counts the number of stpes to be taken
            var heightBeyond:Float = nextHeight
            var steps = 0
            while steps < 2*maxStepsPerPolygon && nextHeight == heightBeyond {
                let posBeyond = curPosition + direction*Float(steps)
                if let height = self.height(forPosition: posBeyond) {
                    heightBeyond = height
                }
                steps = steps + 1
            }
                 
            let stepsTaken = min(steps, maxStepsPerPolygon)
            let w1 = min(1, Float(inc)/Float(max(1, stepsTaken)))
            let w2 = 1 - w1
            height = w1*startHeight + w2*nextHeight
            //Log.engine("startHeight: \(startHeight), newHeight: \(nextHeight), w1: \(w1), w2: \(w2), inc: \(inc), steps: \(steps), final height: \(height!)")
        }
        return height
    }
    
    func backToTrackSegmentStart()
    {
        var lastPos: float2? = .none
        var lastTerrainTile: TerrainTile? = .none
        for terrainTile in self.terrain {
            if let pos = terrainTile.backToStartOfTrackSegment(index: self.gameConfig.segmentIndex) {
                lastPos = pos
                lastTerrainTile = terrainTile
            }
        }
        
        if self.gameConfig.segmentEmpty {
            self.gameConfig.segmentIndex -= 1
        }
        
        for terrainTile in self.terrain {
            terrainTile.updateGameConfig(self.gameConfig, changed: .recording)
        }
        
        if let pos = lastPos,
           let terrainTile = lastTerrainTile {
            var gameConfig = self.gameConfig
            let location = self.geocoder.geoLocationFor(position: float3(x: pos.x, y: 0, z: pos.y), tile: terrainTile.tile)
            gameConfig.location = location
            self.updateGameConfig(self.gameConfig, changed: .location) { }
        }
    }
    fileprivate func buyAlert()
    {
        let dialogMessage = UIAlertController(title: "Buy track feature", message: "Do you want to bay the track feature", preferredStyle: .alert)
        // Create OK button with action handler
        let ok = UIAlertAction(title: "Buy", style: .default, handler: { (action) -> Void in
            print("Ok button tapped")
        })
        // Create Cancel button with action handlder
        let cancel = UIAlertAction(title: "No thanks", style: .cancel) { (action) -> Void in
            print("Cancel button tapped")
        }
        //Add OK and Cancel button to an Alert object
        dialogMessage.addAction(ok)
        dialogMessage.addAction(cancel)
        // Present alert message to user
        self.present(dialogMessage, animated: true, completion: nil)
    }

    func isTrackingFeatureAvailable() -> Bool
    {
        if InAppPurchaseProducts.isPurchased(self.product) {
            return true
        }
        else {
            self.showInAppPurchaseViewController()
        }
        
        if InAppPurchaseProducts.isPurchased(self.product) {
            return true
        }
        return false
    }
    
 /*   fileprivate func render(population: [ModelProxy], renderEncoder: MTLRenderCommandEncoder, uniforms: Uniforms, fragmentUniforms: FragmentUniforms)
    {
        guard let scene = scene else { return }
        
        // render population: at this time we have all the population models with the transforms
        // we need to update all the instance buffers, conatining the transforms
        if population.count > 0 && Preferences.showPopulation {
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
            
            for model in scene.population.models {
                model.render(renderEncoder: renderEncoder, uniforms: uniforms, fragmentUniforms: fragmentUniforms)
            }
        }
    }*/
