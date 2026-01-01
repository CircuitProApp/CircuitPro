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
    case edgeAdded(EdgeID)
    case edgeRemoved(EdgeID)
    case nodeComponentSet(NodeID, ObjectIdentifier)
    case nodeComponentRemoved(NodeID, ObjectIdentifier)
    case edgeComponentSet(EdgeID, ObjectIdentifier)
    case edgeComponentRemoved(EdgeID, ObjectIdentifier)
    case selectionChanged(Set<GraphElementID>)
}
