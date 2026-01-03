//
//  CanvasBindingsKey.swift
//  CircuitPro
//
//  Created by Codex on 1/2/26.
//

import SwiftUI

private struct ConnectionEngineKey: CanvasEnvironmentKey {
    static let defaultValue: (any ConnectionEngine)? = nil
}

private struct CanvasItemsKey: CanvasEnvironmentKey {
    static let defaultValue: Binding<[any CanvasItem]>? = nil
}

extension CanvasEnvironmentValues {
    var connectionEngine: (any ConnectionEngine)? {
        get { self[ConnectionEngineKey.self] }
        set { self[ConnectionEngineKey.self] = newValue }
    }

    var items: Binding<[any CanvasItem]>? {
        get { self[CanvasItemsKey.self] }
        set { self[CanvasItemsKey.self] = newValue }
    }

    func withConnectionEngine(_ engine: (any ConnectionEngine)?) -> CanvasEnvironmentValues {
        var copy = self
        copy.connectionEngine = engine
        return copy
    }

    func withItems(_ items: Binding<[any CanvasItem]>) -> CanvasEnvironmentValues {
        var copy = self
        copy.items = items
        return copy
    }
}
