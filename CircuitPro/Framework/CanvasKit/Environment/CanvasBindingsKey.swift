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

    func updateItem<T: CanvasItem>(
        _ id: UUID,
        as type: T.Type = T.self,
        _ update: (inout T) -> Void
    ) {
        guard let itemsBinding = items else { return }
        var items = itemsBinding.wrappedValue
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        guard var item = items[index] as? T else { return }
        update(&item)
        items[index] = item
        itemsBinding.wrappedValue = items
    }
}
