//
//  ConnectionEdgeID.swift
//  CircuitPro
//
//  Created by Codex on 12/30/25.
//

import Foundation

/// Stable identifier for edges in the unified graph.
struct ConnectionEdgeID: Hashable, Codable {
    let rawValue: UUID

    init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

/// Identifies either a node or an edge in the unified graph.
enum ConnectionElementID: Hashable, Codable {
    case node(ConnectionNodeID)
    case edge(ConnectionEdgeID)

    var rawValue: UUID {
        switch self {
        case .node(let id): return id.rawValue
        case .edge(let id): return id.rawValue
        }
    }

    var nodeID: ConnectionNodeID? {
        if case .node(let id) = self { return id }
        return nil
    }

    var edgeID: ConnectionEdgeID? {
        if case .edge(let id) = self { return id }
        return nil
    }
}
