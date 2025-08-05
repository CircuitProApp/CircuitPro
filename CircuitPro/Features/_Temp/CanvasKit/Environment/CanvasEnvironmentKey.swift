//
//  EnvironmentKey.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/5/25.
//


import CoreGraphics

// 1. The Key Protocol: Defines how to create a new environment value.
public protocol CanvasEnvironmentKey {
    associatedtype Value
    static var defaultValue: Self.Value { get }
}

// 2. The Storage Struct: A type-safe dictionary that the RenderContext will hold.
public struct CanvasEnvironmentValues {
    private var storage: [ObjectIdentifier: Any] = [:]

    public init() {}

    public subscript<K: CanvasEnvironmentKey>(key: K.Type) -> K.Value {
        get {
            guard let value = storage[ObjectIdentifier(key)] as? K.Value else {
                return K.defaultValue
            }
            return value
        }
        set {
            storage[ObjectIdentifier(key)] = newValue
        }
    }
}
