//
//  Population.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 24.01.21.
//  Copyright © 2021 n3xd software studios ag. All rights reserved.
//
import Foundation
import Metal

fileprivate typealias PopulationModelDesc = (name: String, scale: Float, yOffset: Float)

struct ModelProxy
{
    let name: String
    let transforms: [Instances]
    let complexity: ModelComplexityType
}

class Population
{
    var models: [SimpleModel]
    
    init()
    {
        self.models = Population.allModels()
    }
    
    func model(forName name: String) -> SimpleModel?
    {
        return self.models.first { (model) -> Bool in
            model.name == name
        }
    }
    
    fileprivate static func allModels() -> [SimpleModel]
    {
        var simpleModels = [SimpleModel]()
        for modelComplexity in ModelComplexityType.allCases {
            for populationType in PopulationType.allCases {
                let descs = Population.models(forPopulation: populationType, withComplexity: modelComplexity)
                for modelDesc in descs {
                    let model = SimpleModel(name: modelDesc.name, complexity: modelComplexity)
                    model.scale = float3(repeating: modelDesc.scale)
                    simpleModels.append(model)
                }
            }
        }
        return simpleModels
    }

    /**
     Populates the terraintile with real as well as placeholder models. Depending on the level, either of them is rendered.
     */
    func populate(terrainTile: TerrainTile, withStreets streets: MTLTexture?) -> [ModelProxy]
    {
        var modelProxies = [ModelProxy]()
        if !Preferences.showPopulation { return modelProxies }
        
        // creates a list of transforms. These transofors are used for all terrain layers
        var toggleZhalf = false
        var  transforms:[PopulationType:[Transform]] = [.forest:[Transform](), .woods:[Transform](), .gras:[Transform]()]
        let rowColCount = Int(sqrt(Float(TerrainTile.maxPopulationPerTile)))
        let step = TerrainTile.sideLen / Float(rowColCount)
        let smin = step*0.15
        let smid = step*0.5
        let smax = step*0.85
        for row in 0..<rowColCount {
            for col in 0..<rowColCount {
                toggleZhalf = !toggleZhalf
                var transform = Transform()
                transform.position.x = Float(col)*step + .random(in: smin..<smax) - TerrainTile.halfSideLen
                if toggleZhalf {
                    transform.position.z = Float(row)*step + .random(in: smin..<smid) - TerrainTile.halfSideLen
                }
                else {
                    transform.position.z = Float(row)*step + .random(in: smid..<smax) - TerrainTile.halfSideLen
                }
                transform.rotation = float3(x: Float.random(in: -0.1...0.1), y: 0, z: Float.random(in: -0.1...0.1))
                transform.scale = float3(repeating: Float.random(in: 0.9...1.1))
                let position = float2(x: transform.position.x, y: transform.position.z)
                let feature = self.feature(forPosition: position, withStreets: streets)
                if feature == .forest || feature == .woods || feature == .gras {
                    if !isNearStreet(forPosition: position, withStreets: streets) {
                        if let height = terrainTile.height(forPosition: position, useScale: false) {
                            transform.position.y = height
                            var t = transforms[feature]
                            t?.append(transform)
                            transforms[feature] = t
                        }
                        else {
                             Log.warn("Height should alway return a value")
                        }
                    }
                 }
              }
        }
        
        for modelComplexity in ModelComplexityType.allCases {
            Log.load("Models with complexity \(modelComplexity) will be loaded for tile \(terrainTile.tile)")
            for populationType in transforms.keys {
                var offset = 0
                let modelDescs = Population.models(forPopulation: populationType, withComplexity: modelComplexity)
                if var transforms = transforms[populationType] {
                    transforms.shuffle()
                    for modelDesc in modelDescs {
                        let instanceCount = transforms.count / modelDescs.count
                        if instanceCount > 0 {
                            Log.load("Create \(instanceCount) transforms for model \(modelDesc.name) with complexity \(modelComplexity)")
                            var instances = [Instances]()
                            for i in 0..<instanceCount {
                                var transform = transforms[i + offset]
                                transform.position.y = transform.position.y + Float(modelDesc.yOffset)/1000
                                let position = terrainTile.position/modelDesc.scale + transform.position * terrainTile.scale/modelDesc.scale
                                let finalTransform = Transform(position: position, rotation: transform.rotation, scale: transform.scale)
                                let instance = Instances(modelMatrix: finalTransform.modelMatrix, normalMatrix: finalTransform.normalMatrix)
                                instances.append(instance)
                            }
                            let modelProxy = ModelProxy(name: modelDesc.name, transforms: instances, complexity: modelComplexity)
                            modelProxies.append(modelProxy)
                            Log.load("Terrain \(terrainTile.tile) \(populationType) populated with \(instanceCount) instances of model \(modelDesc.name)")
                        }
                        offset = offset + instanceCount
                    }
                }
            }
        }
        
        return modelProxies
    }
    
    func reset()
    {
        for model in models {
            model.updateBuffer(transforms: [Instances]())
        }
    }

    fileprivate func feature(forPosition position: float2, withStreets streets: MTLTexture?, useScale: Bool = false) -> PopulationType
    {
        if let streets = streets {
            let xy = TerrainTile.index(forPosition: position, len: 1024, useScale: useScale)
            let c = ImageHelpers.color(fromTexture: streets, atX: xy.x, atY: xy.y)
            let t = TerrainHelpers.populationType(forColor: c)
            // print("\(xy.x)/\(xy.y): r\(c.red), g\(c.green), b\(c.blue)")
            return t
        }
        return .unknown
    }
    
    fileprivate func isNearStreet(forPosition position: float2, withStreets streets: MTLTexture?, useScale: Bool = false) -> Bool
    {
        let distance:Float = 50
        var u = -TerrainTile.halfSideLen
        while u <= TerrainTile.halfSideLen {
            var v = -TerrainTile.halfSideLen
            while v <= TerrainTile.halfSideLen {
                let x = u/distance
                let y = v/distance
                let feature = self.feature(forPosition: float2(position.x + x, position.y + y), withStreets: streets, useScale: useScale);
                if feature == .street || feature == .gravel {
                    return true
                }
                v = v + TerrainTile.halfSideLen
            }
            u = u + TerrainTile.halfSideLen
        }
        return false
    }
    
    fileprivate static func models(forPopulation populationType: PopulationType, withComplexity complexity: ModelComplexityType) -> [PopulationModelDesc]
    {
        let fir1:PopulationModelDesc =    (name: "TreeFir1.obj",     scale: 27, yOffset: -2)
        let fir2:PopulationModelDesc =    (name: "TreeFir2.obj",     scale: 27, yOffset: -2)
        let fir3:PopulationModelDesc =    (name: "TreeFir3.obj",     scale: 27, yOffset: -2)
        let fir4:PopulationModelDesc =    (name: "TreeFir4.obj",     scale: 27, yOffset: -2)
        let fir5:PopulationModelDesc =    (name: "TreeFir5.obj",     scale: 27, yOffset: -2)
        let fir6:PopulationModelDesc =    (name: "TreeFir6.obj",     scale: 27, yOffset: -2)
        let fir7:PopulationModelDesc =    (name: "TreeFir7.obj",     scale: 27, yOffset: -2)
        let mix4:PopulationModelDesc =    (name: "Mix4.obj",         scale: 10, yOffset: 0)
        let mix8:PopulationModelDesc =    (name: "Mix8.obj",         scale: 10, yOffset: 0)
        let mix17:PopulationModelDesc =   (name: "Mix17.obj",        scale: 10, yOffset: 0)
        let mix18:PopulationModelDesc =   (name: "Mix18.obj",        scale: 10, yOffset: 0)
        let mix23:PopulationModelDesc =   (name: "Mix23.obj",        scale: 10, yOffset: 0)
        //let mix24:PopulationModelDesc =   (name: "Mix24.obj",        scale: 10, yOffset: 0)
        let mix27:PopulationModelDesc =   (name: "Mix27.obj",        scale: 10, yOffset: 0)
        let tree11:PopulationModelDesc =  (name: "Tree11.obj",       scale: 25, yOffset: -5)
        let tree21:PopulationModelDesc =  (name: "Tree21.obj",       scale: 25, yOffset: -5)
        let tree22:PopulationModelDesc =  (name: "Tree22.obj",       scale: 20, yOffset: -5)
        let tree24:PopulationModelDesc =  (name: "Tree24.obj",       scale: 20, yOffset: -5)
        let simple1:PopulationModelDesc = (name: "simplestfir1.obj", scale: 8, yOffset: 20)
        let simple2:PopulationModelDesc = (name: "simplestfir2.obj", scale: 8, yOffset: 20)
        let simple3:PopulationModelDesc = (name: "simplestfir3.obj", scale: 8, yOffset: 20)
        
        var models = [PopulationModelDesc]()
        
        if populationType == .forest {
            if complexity == .full {
                models.append(fir1)
                if Globals.Config.hasMaxPopulation {
                    models.append(fir2)
                    models.append(fir3)
                    models.append(fir4)
                    models.append(fir5)
                    models.append(fir6)
                    models.append(fir7)
                    models.append(tree24)
                    models.append(mix8)
                    models.append(mix17)
                    models.append(mix18)
                    models.append(mix23)
                }
           }
            else if complexity == .placeholder {
                models.append(simple1)
                if Globals.Config.hasMaxPopulation {
                    models.append(simple2)
                    models.append(simple3)
                }
           }
        }
        
        if populationType == .woods {
            if complexity == .full {
                models.append(fir1)
                if Globals.Config.hasMaxPopulation {
                    models.append(tree22)
                    models.append(tree11)
                    models.append(tree21)
                    models.append(tree24)
                    models.append(fir2)
                    models.append(fir3)
                    models.append(mix17)
                    models.append(mix18)
                }
            }
            else if complexity == .placeholder {
                models.append(simple1)
                if Globals.Config.hasMaxPopulation {
                    models.append(simple2)
                    models.append(simple3)
                }
            }
        }
        
        if populationType == .gras {
            if complexity == .full {
                models.append(mix4)
                if Globals.Config.hasMaxPopulation {
                    models.append(mix23)
                    models.append(mix27)
                }
            }
        }
        
        return models
    }
}
