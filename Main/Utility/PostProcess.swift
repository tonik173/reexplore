//
//  PostProcess.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 16.06.2020.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import MetalKit

protocol PostProcess
{
  func postProcess(inputTexture: MTLTexture)
}
