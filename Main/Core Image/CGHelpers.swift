//
//  CGHelpers.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 28.02.21.
//  Copyright © 2021 n3xd software studios ag. All rights reserved.
//
import CoreGraphics

extension CGPoint
{
    func clamp(min lower: CGFloat, max upper: CGFloat) -> CGPoint
    {
        let x = max(lower, min(upper, self.x))
        let y = max(lower, min(upper, self.y))
        return CGPoint(x: x, y: y)
    }
}
