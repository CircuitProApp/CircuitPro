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

private struct ConnectionEngineKey: CanvasEnvironmentKey {
    static let defaultValue: (any ConnectionEngine)? = nil
}

extension CanvasEnvironmentValues {
    var canvasStore: CanvasStore? {
        get { self[CanvasStoreKey.self] }
        set { self[CanvasStoreKey.self] = newValue }
    }

    var connectionEngine: (any ConnectionEngine)? {
        get { self[ConnectionEngineKey.self] }
        set { self[ConnectionEngineKey.self] = newValue }
    }

    func withCanvasStore(_ store: CanvasStore?) -> CanvasEnvironmentValues {
        var copy = self
        copy.canvasStore = store
        return copy
    }

    func withConnectionEngine(_ engine: (any ConnectionEngine)?) -> CanvasEnvironmentValues {
        var copy = self
        copy.connectionEngine = engine
        return copy
    }
}
