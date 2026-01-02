//
//  CanvasStoreKey.swift
//  CircuitPro
//
//  Created by Codex on 9/20/25.
//

import Foundation
import SwiftUI

private struct CanvasStoreKey: CanvasEnvironmentKey {
    static let defaultValue: CanvasStore? = nil
}

private struct ConnectionEngineKey: CanvasEnvironmentKey {
    static let defaultValue: (any ConnectionEngine)? = nil
}

private struct CanvasItemsKey: CanvasEnvironmentKey {
    static let defaultValue: Binding<[any CanvasItem]>? = nil
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

    var items: Binding<[any CanvasItem]>? {
        get { self[CanvasItemsKey.self] }
        set { self[CanvasItemsKey.self] = newValue }
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

    func withItems(_ items: Binding<[any CanvasItem]>) -> CanvasEnvironmentValues {
        var copy = self
        copy.items = items
        return copy
    }
}
