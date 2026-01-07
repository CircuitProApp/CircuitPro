//
//  ConnectionGraphDelta.swift
//  CircuitPro
//
//  Created by Codex on 9/20/25.
//

import Foundation

enum ConnectionGraphDelta {
    case nodeAdded(ConnectionNodeID)
    case nodeRemoved(ConnectionNodeID)
    case edgeAdded(ConnectionEdgeID)
    case edgeRemoved(ConnectionEdgeID)
    case nodeComponentSet(ConnectionNodeID, ObjectIdentifier)
    case nodeComponentRemoved(ConnectionNodeID, ObjectIdentifier)
    case edgeComponentSet(ConnectionEdgeID, ObjectIdentifier)
    case edgeComponentRemoved(ConnectionEdgeID, ObjectIdentifier)
    case selectionChanged(Set<ConnectionElementID>)
}
