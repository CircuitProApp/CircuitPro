//
//  Grid.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/5/25.
//


import CoreGraphics

// 1. Define the data structure you want to use.
struct CanvasGrid {
    var spacing: CGFloat
    var snappingEnabled: Bool
}

// 2. Create a key for your Grid data.
private struct GridKey: CanvasEnvironmentKey {
    static let defaultValue: CanvasGrid = .init(spacing: 10, snappingEnabled: true)
}

// 3. (The Magic) Extend the framework's storage to add a convenient property.
extension CanvasEnvironmentValues {
    var grid: CanvasGrid {
        get { self[GridKey.self] }
        set { self[GridKey.self] = newValue }
    }
}
