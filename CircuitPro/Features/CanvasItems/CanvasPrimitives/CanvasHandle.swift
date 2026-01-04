//
//  CanvasHandle.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 21.06.25.
//

import CoreGraphics

struct CanvasHandle: Hashable {

    enum Kind: Hashable {
        case circleRadius
        case lineStart, lineEnd
        case rectTopLeft, rectTopRight,
                 rectBottomRight, rectBottomLeft
    }

    let kind: Kind
    let position: CGPoint

}

extension CanvasHandle.Kind {
    /// The handle that is geometrically opposite to self, if any.
    var opposite: CanvasHandle.Kind? {
        switch self {
        case .rectTopLeft: return .rectBottomRight
        case .rectTopRight: return .rectBottomLeft
        case .rectBottomRight: return .rectTopLeft
        case .rectBottomLeft: return .rectTopRight
        case .lineStart: return .lineEnd
        case .lineEnd: return .lineStart
        default: return nil
        }
    }
}
