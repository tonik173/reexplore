//
//  ViewController.swift
//  CoreImageToolbox
//
//  Created by Toni Kaufmann on 12.09.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import Cocoa

class ViewController: NSViewController
{
    override func viewDidLoad()
    {
        super.viewDidLoad()
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    internal func image(forName name: String) -> CIImage
    {
        guard
            let url = Bundle.main.url(forResource: name, withExtension: "png"),
            let terrainImage = CIImage(contentsOf: url) else {
                fatalError("Unable to load street image")
        }
        return terrainImage
    }
    
    @IBAction func terrain(_ sender: Any)
    {
        let terrainProcessor = TerrainProcessing()
        let result = terrainProcessor.process(image: image(forName: "z15x17158y11505"))
        //let cg = ImageHelpers.cgImage(fromCIImage: result)
        
        print(result)
    }
    
    @IBAction func createTexture(_ sender: Any)
    {
        let terrainProcessor = TerrainProcessing()
        let result = terrainProcessor.createTexture(withLength: 256, population: .woods)
        //let cg = ImageHelpers.cgImage(fromCIImage: result)
        
        print(result)
    }
    
    
}

