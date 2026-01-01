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
    private(set) var edges: Set<EdgeID> = []
    var selection: Set<GraphElementID> = [] {
        didSet { onDelta?(.selectionChanged(selection)) }
    }

    var onDelta: ((UnifiedGraphDelta) -> Void)?

    private var nodeComponentStorage: [ObjectIdentifier: [NodeID: Any]] = [:]
    private var edgeComponentStorage: [ObjectIdentifier: [EdgeID: Any]] = [:]

    @discardableResult
    func addNode(_ id: NodeID = NodeID()) -> NodeID {
        nodes.insert(id)
        onDelta?(.nodeAdded(id))
        return id
    }

    func removeNode(_ id: NodeID) {
        guard nodes.remove(id) != nil else { return }
        for key in nodeComponentStorage.keys {
            nodeComponentStorage[key]?.removeValue(forKey: id)
        }
        selection.remove(.node(id))
        onDelta?(.nodeRemoved(id))
    }

    @discardableResult
    func addEdge(_ id: EdgeID = EdgeID()) -> EdgeID {
        edges.insert(id)
        onDelta?(.edgeAdded(id))
        return id
    }

    func removeEdge(_ id: EdgeID) {
        guard edges.remove(id) != nil else { return }
        for key in edgeComponentStorage.keys {
            edgeComponentStorage[key]?.removeValue(forKey: id)
        }
        selection.remove(.edge(id))
        onDelta?(.edgeRemoved(id))
    }

    func reset() {
        nodes.removeAll()
        edges.removeAll()
        nodeComponentStorage.removeAll()
        edgeComponentStorage.removeAll()
        selection.removeAll()
    }

    func setComponent<T>(_ component: T, for id: NodeID) {
        let key = ObjectIdentifier(T.self)
        if nodeComponentStorage[key] == nil {
            nodeComponentStorage[key] = [:]
        }
        nodeComponentStorage[key]?[id] = component
        onDelta?(.nodeComponentSet(id, key))
    }

    func setComponent<T>(_ component: T, for id: EdgeID) {
        let key = ObjectIdentifier(T.self)
        if edgeComponentStorage[key] == nil {
            edgeComponentStorage[key] = [:]
        }
        edgeComponentStorage[key]?[id] = component
        onDelta?(.edgeComponentSet(id, key))
    }

    func removeComponent<T>(_ type: T.Type, for id: NodeID) {
        let key = ObjectIdentifier(T.self)
        nodeComponentStorage[key]?.removeValue(forKey: id)
        onDelta?(.nodeComponentRemoved(id, key))
    }

    func removeComponent<T>(_ type: T.Type, for id: EdgeID) {
        let key = ObjectIdentifier(T.self)
        edgeComponentStorage[key]?.removeValue(forKey: id)
        onDelta?(.edgeComponentRemoved(id, key))
    }

    func component<T>(_ type: T.Type, for id: NodeID) -> T? {
        let key = ObjectIdentifier(T.self)
        return nodeComponentStorage[key]?[id] as? T
    }

    func component<T>(_ type: T.Type, for id: EdgeID) -> T? {
        let key = ObjectIdentifier(T.self)
        return edgeComponentStorage[key]?[id] as? T
    }

    func nodeIDs<T>(with componentType: T.Type) -> [NodeID] {
        let key = ObjectIdentifier(T.self)
        guard let keys = nodeComponentStorage[key]?.keys else { return [] }
        return Array(keys)
    }

    func edgeIDs<T>(with componentType: T.Type) -> [EdgeID] {
        let key = ObjectIdentifier(T.self)
        guard let keys = edgeComponentStorage[key]?.keys else { return [] }
        return Array(keys)
    }

    func components<T>(_ type: T.Type) -> [(NodeID, T)] {
        let key = ObjectIdentifier(T.self)
        guard let items = nodeComponentStorage[key] else { return [] }
        return items.compactMap { id, value in
            guard let typed = value as? T else { return nil }
            return (id, typed)
        }
    }

    func edgeComponents<T>(_ type: T.Type) -> [(EdgeID, T)] {
        let key = ObjectIdentifier(T.self)
        guard let items = edgeComponentStorage[key] else { return [] }
        return items.compactMap { id, value in
            guard let typed = value as? T else { return nil }
            return (id, typed)
        }
    }

    func componentsConforming<T>(_ type: T.Type) -> [(NodeID, T)] {
        var results: [(NodeID, T)] = []
        for items in nodeComponentStorage.values {
            for (id, value) in items {
                if let typed = value as? T {
                    results.append((id, typed))
                }
            }
        }
        return results
    }

    func allComponentsConforming<T>(_ type: T.Type) -> [(GraphElementID, T)] {
        var results: [(GraphElementID, T)] = []
        for items in nodeComponentStorage.values {
            for (id, value) in items {
                if let typed = value as? T {
                    results.append((.node(id), typed))
                }
            }
        }
        for items in edgeComponentStorage.values {
            for (id, value) in items {
                if let typed = value as? T {
                    results.append((.edge(id), typed))
                }
            }
        }
        return results
    }

    func hasAnyComponent(for id: NodeID) -> Bool {
        for storage in nodeComponentStorage.values {
            if storage[id] != nil {
                return true
            }
        }
        return false
    }

    func hasAnyComponent(for id: EdgeID) -> Bool {
        for storage in edgeComponentStorage.values {
            if storage[id] != nil {
                return true
            }
        }
        return false
    }

    func hasAnyComponent(for id: GraphElementID) -> Bool {
        switch id {
        case .node(let nodeID):
            return hasAnyComponent(for: nodeID)
        case .edge(let edgeID):
            return hasAnyComponent(for: edgeID)
        }
    }
}
