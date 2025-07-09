//
//  ConnectionSegment.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/9/25.
//

import Foundation
import CoreGraphics

struct ConnectionSegment: Identifiable {
    var id: UUID
    var start: CGPoint
    var end: CGPoint

    var orientation: LineOrientation {
        // A segment is considered vertical if the x-coordinates are the same.
        // Otherwise, it's horizontal. This assumes segments are always orthogonal.
        if start.x == end.x {
            return .vertical
        } else {
            return .horizontal
        }
    }
}
