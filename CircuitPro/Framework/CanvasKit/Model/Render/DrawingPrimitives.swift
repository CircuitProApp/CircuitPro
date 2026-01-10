//
//  DrawingPrimitives.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/8/25.
//

import AppKit

/// A drawing primitive paired with an optional layer target.
struct LayeredDrawingPrimitive {
    var primitive: DrawingPrimitive
    var layerId: UUID?

    init(_ primitive: DrawingPrimitive, layerId: UUID?) {
        self.primitive = primitive
        self.layerId = layerId
    }
}

/// An enum that describes a single, high-level drawing operation.
enum DrawingPrimitive {
    case fill(path: CGPath, color: CGColor, rule: CAShapeLayerFillRule = .nonZero, clipPath: CGPath? = nil)
    case stroke(path: CGPath, color: CGColor, lineWidth: CGFloat, lineCap: CAShapeLayerLineCap = .round, lineJoin: CAShapeLayerLineJoin = .miter, miterLimit: CGFloat = 10, lineDash: [NSNumber]? = nil, clipPath: CGPath? = nil)
}

extension DrawingPrimitive {
    /// Helper to apply a transform to a DrawingPrimitive.
    func applying(transform: inout CGAffineTransform) -> DrawingPrimitive {
        switch self {
        case let .fill(path, color, rule, clipPath):
            var clipped = clipPath
            if let clipPath {
                clipped = clipPath.copy(using: &transform) ?? clipPath
            }
            return .fill(
                path: path.copy(using: &transform) ?? path,
                color: color,
                rule: rule,
                clipPath: clipped
            )

        case let .stroke(path, color, lineWidth, lineCap, lineJoin, miterLimit, lineDash, clipPath):
            var clipped = clipPath
            if let clipPath {
                clipped = clipPath.copy(using: &transform) ?? clipPath
            }
            return .stroke(
                path: path.copy(using: &transform) ?? path,
                color: color,
                lineWidth: lineWidth,
                lineCap: lineCap,
                lineJoin: lineJoin,
                miterLimit: miterLimit,
                lineDash: lineDash,
                clipPath: clipped
            )
        }
    }
}
