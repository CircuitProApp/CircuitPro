//
//  DrawingPrimitives.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/8/25.
//

import AppKit

/// An enum that describes a single, high-level drawing operation.
enum DrawingPrimitive {
    case fill(path: CGPath, color: CGColor, rule: CAShapeLayerFillRule = .nonZero)
    case stroke(path: CGPath, color: CGColor, lineWidth: CGFloat, lineCap: CAShapeLayerLineCap = .round, lineJoin: CAShapeLayerLineJoin = .miter, miterLimit: CGFloat = 10, lineDash: [NSNumber]? = nil)
}

extension DrawingPrimitive {
    /// Helper to apply a transform to a DrawingPrimitive.
    func applying(transform: inout CGAffineTransform) -> DrawingPrimitive {
        switch self {
        case let .fill(path, color, rule):
            return .fill(
                path: path.copy(using: &transform) ?? path,
                color: color,
                rule: rule
            )

        case let .stroke(path, color, lineWidth, lineCap, lineJoin, miterLimit, lineDash):
            return .stroke(
                path: path.copy(using: &transform) ?? path,
                color: color,
                lineWidth: lineWidth,
                lineCap: lineCap,
                lineJoin: lineJoin,
                miterLimit: miterLimit,
                lineDash: lineDash
            )
        }
    }
}
