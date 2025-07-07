//
//  Edge.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/6/25.
//

import CoreGraphics
import Foundation

struct Edge: Identifiable, Hashable {
    let id: UUID
    var startNodeID: UUID
    var endNodeID: UUID
}
