//
//  WireEdge.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import SwiftUI

struct WireEdge: Identifiable, Hashable {
    let id: UUID
    let start: WireVertex.ID
    let end: WireVertex.ID
}
