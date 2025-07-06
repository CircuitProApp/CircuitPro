//
//  Node.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/6/25.
//

import CoreGraphics
import Foundation

enum NodeKind {
    case endpoint
    case junction
}

struct Node: Identifiable, Hashable {
    let id: UUID
    var point: CGPoint
    var kind: NodeKind
}
