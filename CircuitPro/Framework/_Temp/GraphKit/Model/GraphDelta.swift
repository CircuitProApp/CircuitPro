//
//  GraphDelta.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import Foundation

typealias GroupID = UUID

struct GraphDelta {
    var createdVertices: Set<UUID> = []
    var deletedVertices: Set<UUID> = []
    var movedVertices: [UUID: (from: CGPoint, to: CGPoint)] = [:]

    var createdEdges: Set<UUID> = []
    var deletedEdges: Set<UUID> = []

    var changedOwnership: [UUID: (from: VertexOwnership, to: VertexOwnership)] = [:]
    var changedGroupIDs: [UUID: (from: UUID?, to: UUID?)] = [:]
}
