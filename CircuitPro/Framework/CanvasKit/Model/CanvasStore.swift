//
//  CanvasStore.swift
//  CircuitPro
//
//  Created by Codex on 9/20/25.
//

import Foundation
import Observation

/// A generic, domain-agnostic state container for a canvas scene graph.
@MainActor
@Observable
final class CanvasStore {
    var nodes: [BaseNode] = []
    var selection: Set<UUID> = []
    var onNodesChanged: (([BaseNode]) -> Void)?

    func setNodes(_ nodes: [BaseNode]) {
        self.nodes = nodes
        onNodesChanged?(nodes)
    }

    func addNode(_ node: BaseNode) {
        nodes.append(node)
        onNodesChanged?(nodes)
    }

    func removeNodes(ids: Set<UUID>) {
        nodes.removeAll { ids.contains($0.id) }
        onNodesChanged?(nodes)
    }
}
