//
//  SchematicGraph.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/16/25.
//

import Foundation
import SwiftUI

struct ConnectionVertex: Identifiable, Hashable {
    let id: UUID
    var point: CGPoint
}

struct ConnectionEdge: Identifiable, Hashable {
    let id: UUID
    let start: ConnectionVertex.ID
    let end: ConnectionVertex.ID
}

@Observable
class SchematicGraph {
    private(set) var vertices: [ConnectionVertex.ID: ConnectionVertex] = [:]
    private(set) var edges: [ConnectionEdge.ID: ConnectionEdge] = [:]
    
    /// Adjacency list for efficient graph traversal. Maps a vertex ID to the set of edge IDs connected to it.
    private(set) var adjacency: [ConnectionVertex.ID: Set<ConnectionEdge.ID>] = [:]


}
