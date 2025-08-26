//
//  GraphVertex.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import SwiftUI

struct GraphVertex: Identifiable, Hashable {
    let id: UUID
    var point: CGPoint
    var ownership: VertexOwnership
    var groupID: UUID?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: GraphVertex, rhs: GraphVertex) -> Bool { lhs.id == rhs.id }
}
