//
//  GraphEdge.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import SwiftUI

struct GraphEdge: Identifiable, Hashable {
    let id: UUID
    let start: GraphVertex.ID
    let end: GraphVertex.ID
}
