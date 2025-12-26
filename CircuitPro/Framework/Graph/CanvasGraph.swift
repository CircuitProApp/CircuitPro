//
//  CanvasGraph.swift
//  CircuitPro
//
//  Created by Codex on 9/20/25.
//

import Foundation
import Observation

@Observable
final class CanvasGraph {
    private(set) var nodes: Set<NodeID> = []
    var selection: Set<NodeID> = [] {
        didSet { onDelta?(.selectionChanged(selection)) }
    }

    var onDelta: ((UnifiedGraphDelta) -> Void)?

    private var componentStorage: [ObjectIdentifier: [NodeID: Any]] = [:]

    @discardableResult
    func addNode(_ id: NodeID = NodeID()) -> NodeID {
        nodes.insert(id)
        onDelta?(.nodeAdded(id))
        return id
    }

    func removeNode(_ id: NodeID) {
        guard nodes.remove(id) != nil else { return }
        for key in componentStorage.keys {
            componentStorage[key]?.removeValue(forKey: id)
        }
        selection.remove(id)
        onDelta?(.nodeRemoved(id))
    }

    func reset() {
        nodes.removeAll()
        componentStorage.removeAll()
        selection.removeAll()
    }

    func setComponent<T>(_ component: T, for id: NodeID) {
        let key = ObjectIdentifier(T.self)
        if componentStorage[key] == nil {
            componentStorage[key] = [:]
        }
        componentStorage[key]?[id] = component
        onDelta?(.componentSet(id, key))
    }

    func removeComponent<T>(_ type: T.Type, for id: NodeID) {
        let key = ObjectIdentifier(T.self)
        componentStorage[key]?.removeValue(forKey: id)
        onDelta?(.componentRemoved(id, key))
    }

    func component<T>(_ type: T.Type, for id: NodeID) -> T? {
        let key = ObjectIdentifier(T.self)
        return componentStorage[key]?[id] as? T
    }

    func nodeIDs<T>(with componentType: T.Type) -> [NodeID] {
        let key = ObjectIdentifier(T.self)
        guard let keys = componentStorage[key]?.keys else { return [] }
        return Array(keys)
    }

    func components<T>(_ type: T.Type) -> [(NodeID, T)] {
        let key = ObjectIdentifier(T.self)
        guard let items = componentStorage[key] else { return [] }
        return items.compactMap { id, value in
            guard let typed = value as? T else { return nil }
            return (id, typed)
        }
    }

    func hasAnyComponent(for id: NodeID) -> Bool {
        for storage in componentStorage.values {
            if storage[id] != nil {
                return true
            }
        }
        return false
    }
}
