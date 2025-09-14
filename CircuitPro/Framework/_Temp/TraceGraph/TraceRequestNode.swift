//
//  TraceRequestNode.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/15/25.
//

import SwiftUI
import AppKit

/// A request to create a multi-segment trace path.
final class TraceRequestNode: BaseNode {
    let points: [CGPoint]
    let width: CGFloat
    let layerId: UUID

    init(points: [CGPoint], width: CGFloat, layerId: UUID) {
        self.points = points; self.width = width; self.layerId = layerId
        super.init()
    }
}

