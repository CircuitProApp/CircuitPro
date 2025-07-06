//
//  Net.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/6/25.
//

import CoreGraphics
import Foundation

struct Net: Identifiable, Hashable {
    let id: UUID
    var nodeByID: [UUID: Node] = [:]
    var edges: [Edge] = []
}
