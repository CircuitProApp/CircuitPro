//
//  ConnectionGraph.swift
//  CircuitPro
//
//  Created by Codex on 9/20/25.
//

import Foundation
import Observation

@Observable
final class ConnectionGraph {
    private(set) var nodes: Set<ConnectionNodeID> = []
    private(set) var edges: Set<ConnectionEdgeID> = []
    var selection: Set<ConnectionElementID> = [] {
        didSet { emit(.selectionChanged(selection)) }
    }

    var onDelta: ((ConnectionGraphDelta) -> Void)?
    private var observers: [UUID: (ConnectionGraphDelta) -> Void] = [:]

    @discardableResult
    func addObserver(_ handler: @escaping (ConnectionGraphDelta) -> Void) -> UUID {
        let token = UUID()
        observers[token] = handler
        return token
    }

    func removeObserver(_ token: UUID) {
        observers.removeValue(forKey: token)
    }

    private func emit(_ delta: ConnectionGraphDelta) {
        onDelta?(delta)
        for handler in observers.values {
            handler(delta)
        }
    }

    private var nodeComponentStorage: [ObjectIdentifier: [ConnectionNodeID: Any]] = [:]
    private var edgeComponentStorage: [ObjectIdentifier: [ConnectionEdgeID: Any]] = [:]

    @discardableResult
    func addNode(_ id: ConnectionNodeID = ConnectionNodeID()) -> ConnectionNodeID {
        nodes.insert(id)
        emit(.nodeAdded(id))
        return id
    }

    func removeNode(_ id: ConnectionNodeID) {
        guard nodes.remove(id) != nil else { return }
        for key in nodeComponentStorage.keys {
            nodeComponentStorage[key]?.removeValue(forKey: id)
        }
        selection.remove(.node(id))
        emit(.nodeRemoved(id))
    }

    @discardableResult
    func addEdge(_ id: ConnectionEdgeID = ConnectionEdgeID()) -> ConnectionEdgeID {
        edges.insert(id)
        emit(.edgeAdded(id))
        return id
    }

    func removeEdge(_ id: ConnectionEdgeID) {
        guard edges.remove(id) != nil else { return }
        for key in edgeComponentStorage.keys {
            edgeComponentStorage[key]?.removeValue(forKey: id)
        }
        selection.remove(.edge(id))
        emit(.edgeRemoved(id))
    }

    func reset() {
        nodes.removeAll()
        edges.removeAll()
        nodeComponentStorage.removeAll()
        edgeComponentStorage.removeAll()
        selection.removeAll()
    }

    func setComponent<T>(_ component: T, for id: ConnectionNodeID) {
        let key = ObjectIdentifier(T.self)
        if nodeComponentStorage[key] == nil {
            nodeComponentStorage[key] = [:]
        }
        nodeComponentStorage[key]?[id] = component
        emit(.nodeComponentSet(id, key))
    }

    func setComponent<T>(_ component: T, for id: ConnectionEdgeID) {
        let key = ObjectIdentifier(T.self)
        if edgeComponentStorage[key] == nil {
            edgeComponentStorage[key] = [:]
        }
        edgeComponentStorage[key]?[id] = component
        emit(.edgeComponentSet(id, key))
    }

    func removeComponent<T>(_ type: T.Type, for id: ConnectionNodeID) {
        let key = ObjectIdentifier(T.self)
        nodeComponentStorage[key]?.removeValue(forKey: id)
        emit(.nodeComponentRemoved(id, key))
    }

    func removeComponent<T>(_ type: T.Type, for id: ConnectionEdgeID) {
        let key = ObjectIdentifier(T.self)
        edgeComponentStorage[key]?.removeValue(forKey: id)
        emit(.edgeComponentRemoved(id, key))
    }

    func component<T>(_ type: T.Type, for id: ConnectionNodeID) -> T? {
        let key = ObjectIdentifier(T.self)
        return nodeComponentStorage[key]?[id] as? T
    }

    func component<T>(_ type: T.Type, for id: ConnectionEdgeID) -> T? {
        let key = ObjectIdentifier(T.self)
        return edgeComponentStorage[key]?[id] as? T
    }

    func nodeIDs<T>(with componentType: T.Type) -> [ConnectionNodeID] {
        let key = ObjectIdentifier(T.self)
        guard let keys = nodeComponentStorage[key]?.keys else { return [] }
        return Array(keys)
    }

    func edgeIDs<T>(with componentType: T.Type) -> [ConnectionEdgeID] {
        let key = ObjectIdentifier(T.self)
        guard let keys = edgeComponentStorage[key]?.keys else { return [] }
        return Array(keys)
    }

    func components<T>(_ type: T.Type) -> [(ConnectionNodeID, T)] {
        let key = ObjectIdentifier(T.self)
        guard let items = nodeComponentStorage[key] else { return [] }
        return items.compactMap { id, value in
            guard let typed = value as? T else { return nil }
            return (id, typed)
        }
    }

    func edgeComponents<T>(_ type: T.Type) -> [(ConnectionEdgeID, T)] {
        let key = ObjectIdentifier(T.self)
        guard let items = edgeComponentStorage[key] else { return [] }
        return items.compactMap { id, value in
            guard let typed = value as? T else { return nil }
            return (id, typed)
        }
    }

    func componentsConforming<T>(_ type: T.Type) -> [(ConnectionNodeID, T)] {
        var results: [(ConnectionNodeID, T)] = []
        for items in nodeComponentStorage.values {
            for (id, value) in items {
                if let typed = value as? T {
                    results.append((id, typed))
                }
            }
        }
        return results
    }

    func allComponentsConforming<T>(_ type: T.Type) -> [(ConnectionElementID, T)] {
        var results: [(ConnectionElementID, T)] = []
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

    func hasAnyComponent(for id: ConnectionNodeID) -> Bool {
        for storage in nodeComponentStorage.values {
            if storage[id] != nil {
                return true
            }
        }
        return false
    }

    func hasAnyComponent(for id: ConnectionEdgeID) -> Bool {
        for storage in edgeComponentStorage.values {
            if storage[id] != nil {
                return true
            }
        }
        return false
    }

    func hasAnyComponent(for id: ConnectionElementID) -> Bool {
        switch id {
        case .node(let nodeID):
            return hasAnyComponent(for: nodeID)
        case .edge(let edgeID):
            return hasAnyComponent(for: edgeID)
        }
    }
}
