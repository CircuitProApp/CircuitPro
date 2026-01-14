//
//  CanvasBindingsKey.swift
//  CircuitPro
//
//  Created by Codex on 1/2/26.
//

private struct ConnectionEngineKey: CanvasEnvironmentKey {
    static let defaultValue: (any ConnectionEngine)? = nil
}

extension CanvasEnvironmentValues {
    var connectionEngine: (any ConnectionEngine)? {
        get { self[ConnectionEngineKey.self] }
        set { self[ConnectionEngineKey.self] = newValue }
    }

    func withConnectionEngine(_ engine: (any ConnectionEngine)?) -> CanvasEnvironmentValues {
        var copy = self
        copy.connectionEngine = engine
        return copy
    }
}
