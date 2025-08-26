//
//  WireVertex.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import SwiftUI

struct WireVertex: Identifiable, Hashable {
    let id: UUID
    var point: CGPoint
    var ownership: VertexOwnership
    var netID: UUID?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: WireVertex, rhs: WireVertex) -> Bool { lhs.id == rhs.id }
}
