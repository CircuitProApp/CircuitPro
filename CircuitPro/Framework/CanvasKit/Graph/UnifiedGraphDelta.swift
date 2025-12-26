//
//  UnifiedGraphDelta.swift
//  CircuitPro
//
//  Created by Codex on 9/20/25.
//

import Foundation

enum UnifiedGraphDelta {
    case nodeAdded(NodeID)
    case nodeRemoved(NodeID)
    case componentSet(NodeID, ObjectIdentifier)
    case componentRemoved(NodeID, ObjectIdentifier)
    case selectionChanged(Set<NodeID>)
}
