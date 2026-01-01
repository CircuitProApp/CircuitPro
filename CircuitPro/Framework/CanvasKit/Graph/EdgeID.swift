//
//  EdgeID.swift
//  CircuitPro
//
//  Created by Codex on 12/30/25.
//

import Foundation

/// Stable identifier for edges in the unified graph.
struct EdgeID: Hashable, Codable {
    let rawValue: UUID

    init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

/// Identifies either a node or an edge in the unified graph.
enum GraphElementID: Hashable, Codable {
    case node(NodeID)
    case edge(EdgeID)

    var rawValue: UUID {
        switch self {
        case .node(let id): return id.rawValue
        case .edge(let id): return id.rawValue
        }
    }

    var nodeID: NodeID? {
        if case .node(let id) = self { return id }
        return nil
    }

    var edgeID: EdgeID? {
        if case .edge(let id) = self { return id }
        return nil
    }
}
