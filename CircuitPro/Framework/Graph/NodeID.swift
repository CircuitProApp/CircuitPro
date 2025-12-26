//
//  NodeID.swift
//  CircuitPro
//
//  Created by Codex on 9/20/25.
//

import Foundation

/// Stable identifier for nodes in the unified graph.
struct NodeID: Hashable, Codable {
    let rawValue: UUID

    init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}
