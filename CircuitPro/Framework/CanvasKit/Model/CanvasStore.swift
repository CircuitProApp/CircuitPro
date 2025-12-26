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
    var selection: Set<UUID> = [] {
        didSet {
            onDelta?(.selectionChanged(selection))
        }
    }
    var onNodesChanged: (([BaseNode]) -> Void)?
    var onDelta: ((CanvasStoreDelta) -> Void)?

    func setNodes(_ nodes: [BaseNode]) {
        self.nodes = nodes
        onNodesChanged?(nodes)
        onDelta?(.reset(nodes: nodes))
    }

    func addNode(_ node: BaseNode) {
        nodes.append(node)
        onNodesChanged?(nodes)
        onDelta?(.nodesAdded([node]))
    }

    func removeNodes(ids: Set<UUID>) {
        nodes.removeAll { ids.contains($0.id) }
        onNodesChanged?(nodes)
        onDelta?(.nodesRemoved(ids: ids))
    }
}
