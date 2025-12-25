//
//  CanvasStoreKey.swift
//  CircuitPro
//
//  Created by Codex on 9/20/25.
//

import Foundation

private struct CanvasStoreKey: CanvasEnvironmentKey {
    static let defaultValue: CanvasStore? = nil
}

extension CanvasEnvironmentValues {
    var canvasStore: CanvasStore? {
        get { self[CanvasStoreKey.self] }
        set { self[CanvasStoreKey.self] = newValue }
    }

    func withCanvasStore(_ store: CanvasStore?) -> CanvasEnvironmentValues {
        var copy = self
        copy.canvasStore = store
        return copy
    }
}
