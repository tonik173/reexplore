//
//  MathLibrary.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 16.06.2020.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import simd

public typealias int2 = SIMD2<Int32>
public typealias float2 = SIMD2<Float>
public typealias float3 = SIMD3<Float>
public typealias float4 = SIMD4<Float>

let π = Float.pi
let epsilon = 1e-14

extension Float {
    var radiansToDegrees: Float {
        return (self / π) * 180
    }
    var degreesToRadians: Float {
        return (self / 180) * π
    }
}

extension Double {
    /// Rounds the double to decimal places value
    func rounded(toPlaces places:Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

extension float2 {
    var isZero: Bool {
        return abs(x) < Float(epsilon) && abs(y) < Float(epsilon)
    }
}

struct Rectangle
{
    var left: Float = 0
    var right: Float = 0
    var top: Float = 0
    var bottom: Float = 0
    
    func move(x: Float, y: Float) -> Rectangle
    {    
        return Rectangle(left: left + x, right: right + x, top: top + y, bottom: bottom + y)
    }
    
    var center: float2 {
        return float2(x: (right - left)/2 + left, y: (top - bottom)/2 + bottom)
    }
}

// MARK:- float4x4
extension float4x4 {
    // MARK:- Translate
    init(translation: float3) {
        let matrix = float4x4(
            [            1,             0,             0, 0],
            [            0,             1,             0, 0],
            [            0,             0,             1, 0],
            [translation.x, translation.y, translation.z, 1]
        )
        self = matrix
    }
    
    // MARK:- Scale
    init(scaling: float3) {
        let matrix = float4x4(
            [scaling.x,         0,         0, 0],
            [        0, scaling.y,         0, 0],
            [        0,         0, scaling.z, 0],
            [        0,         0,         0, 1]
        )
        self = matrix
    }
    
    init(scaling: Float) {
        self = matrix_identity_float4x4
        columns.3.w = 1 / scaling
    }
    
    // MARK:- Rotate
    init(rotationX angle: Float) {
        let matrix = float4x4(
            [1,           0,          0, 0],
            [0,  cos(angle), sin(angle), 0],
            [0, -sin(angle), cos(angle), 0],
            [0,           0,          0, 1]
        )
        self = matrix
    }
    
    init(rotationY angle: Float) {
        let matrix = float4x4(
            [cos(angle), 0, -sin(angle), 0],
            [         0, 1,           0, 0],
            [sin(angle), 0,  cos(angle), 0],
            [         0, 0,           0, 1]
        )
        self = matrix
    }
    
    init(rotationZ angle: Float) {
        let matrix = float4x4(
            [ cos(angle), sin(angle), 0, 0],
            [-sin(angle), cos(angle), 0, 0],
            [          0,          0, 1, 0],
            [          0,          0, 0, 1]
        )
        self = matrix
    }
    
    init(rotation angle: float3) {
        let rotationX = float4x4(rotationX: angle.x)
        let rotationY = float4x4(rotationY: angle.y)
        let rotationZ = float4x4(rotationZ: angle.z)
        self = rotationX * rotationY * rotationZ
    }
    
    init(rotationYXZ angle: float3) {
        let rotationX = float4x4(rotationX: angle.x)
        let rotationY = float4x4(rotationY: angle.y)
        let rotationZ = float4x4(rotationZ: angle.z)
        self = rotationY * rotationX * rotationZ
    }
    
    // MARK:- Identity
    static func identity() -> float4x4 {
        return matrix_identity_float4x4
    }
    
    // MARK:- Upper left 3x3
    var upperLeft: float3x3 {
        let x = columns.0.xyz
        let y = columns.1.xyz
        let z = columns.2.xyz
        return float3x3(columns: (x, y, z))
    }
    
    // MARK: - Left handed projection matrix
    init(projectionFov fov: Float, near: Float, far: Float, aspect: Float, lhs: Bool = true) {
        let y = 1 / tan(fov * 0.5)
        let x = y / aspect
        let z = lhs ? far / (far - near) : far / (near - far)
        let X = float4( x,  0,  0,  0)
        let Y = float4( 0,  y,  0,  0)
        let Z = lhs ? float4( 0,  0,  z, 1) : float4( 0,  0,  z, -1)
        let W = lhs ? float4( 0,  0,  z * -near,  0) : float4( 0,  0,  z * near,  0)
        self.init()
        columns = (X, Y, Z, W)
    }
    
    // left-handed LookAt
    init(eye: float3, center: float3, up: float3) {
        let z = normalize(center-eye)
        let x = normalize(cross(up, z))
        let y = cross(z, x)
        
        let X = float4(x.x, y.x, z.x, 0)
        let Y = float4(x.y, y.y, z.y, 0)
        let Z = float4(x.z, y.z, z.z, 0)
        let W = float4(-dot(x, eye), -dot(y, eye), -dot(z, eye), 1)
        
        self.init()
        columns = (X, Y, Z, W)
    }
    
    // MARK:- Orthographic matrix
    init(orthoLeft left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float) {
        let X = float4(2 / (right - left), 0, 0, 0)
        let Y = float4(0, 2 / (top - bottom), 0, 0)
        let Z = float4(0, 0, 1 / (far - near), 0)
        let W = float4((left + right) / (left - right),
                       (top + bottom) / (bottom - top),
                       near / (near - far),
                       1)
        self.init()
        columns = (X, Y, Z, W)
    }
    
    init(orthographic rect: Rectangle, near: Float, far: Float) {
        let X = float4(2 / (rect.right - rect.left), 0, 0, 0)
        let Y = float4(0, 2 / (rect.top - rect.bottom), 0, 0)
        let Z = float4(0, 0, 1 / (far - near), 0)
        let W = float4((rect.left + rect.right) / (rect.left - rect.right),
                       (rect.top + rect.bottom) / (rect.bottom - rect.top),
                       near / (near - far),
                       1)
        self.init()
        columns = (X, Y, Z, W)
    }
    
    // convert double4x4 to float4x4
    init(_ m: matrix_double4x4) {
        self.init()
        let matrix: float4x4 = float4x4(float4(m.columns.0),
                                        float4(m.columns.1),
                                        float4(m.columns.2),
                                        float4(m.columns.3))
        self = matrix
    }
}

// MARK:- float3x3
extension float3x3
{
    init(normalFrom4x4 matrix: float4x4) {
        self.init()
        columns = matrix.upperLeft.inverse.transpose.columns
    }
}

// MARK:- float4
extension float4
{
    var xyz: float3 {
        get {
            return float3(x, y, z)
        }
        set {
            x = newValue.x
            y = newValue.y
            z = newValue.z
        }
    }
    
    // convert from double4
    init(_ d: SIMD4<Double>) {
        self.init()
        self = [Float(d.x), Float(d.y), Float(d.z), Float(d.w)]
    }
}


struct Math
{
    static func barryCentric(p1: float3, p2: float3, p3: float3, position pos: float2) -> Float
    {
        let det = (p2.z - p3.z) * (p1.x - p3.x) + (p3.x - p2.x) * (p1.z - p3.z)
        let l1 = ((p2.z - p3.z) * (pos.x - p3.x) + (p3.x - p2.x) * (pos.y - p3.z)) / det
        let l2 = ((p3.z - p1.z) * (pos.x - p3.x) + (p1.x - p3.x) * (pos.y - p3.z)) / det
        let l3 = 1 - l1 - l2
        return l1 * p1.y + l2 * p2.y + l3 * p3.y
    }
}
