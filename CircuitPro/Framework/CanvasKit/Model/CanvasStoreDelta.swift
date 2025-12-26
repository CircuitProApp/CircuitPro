//
//  CanvasStoreDelta.swift
//  CircuitPro
//
//  Created by Codex on 9/20/25.
//

import Foundation

enum CanvasStoreDelta {
    case reset(nodes: [BaseNode])
    case nodesAdded([BaseNode])
    case nodesRemoved(ids: Set<UUID>)
    case selectionChanged(Set<UUID>)
}
