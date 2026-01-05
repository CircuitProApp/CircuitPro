//
//  WireComponents.swift
//  CircuitPro
//
//  Created by Codex on 9/21/25.
//

import AppKit
import CoreGraphics
import Foundation

struct WireVertexComponent: Hashable, Drawable {
    let id: UUID
    var point: CGPoint
    var clusterID: UUID?
    var ownership: VertexOwnership
    var degree: Int

    func makeDrawingPrimitives(in context: RenderContext) -> [LayeredDrawingPrimitive] {
        let needsDot: Bool
        switch ownership {
        case .pin:
            needsDot = degree > 1
        default:
            needsDot = degree > 2
        }
        guard needsDot else { return [] }

        let dotRect = CGRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4)
        let dotPath = CGPath(ellipseIn: dotRect, transform: nil)
        let dotPrimitive = DrawingPrimitive.fill(
            path: dotPath,
            color: NSColor.controlAccentColor.cgColor
        )
        return [LayeredDrawingPrimitive(dotPrimitive, layerId: nil)]
    }
}

struct WireEdgeComponent: Hashable, Drawable, HitTestable, Bounded, Layerable {
    let id: UUID
    var start: ConnectionNodeID
    var end: ConnectionNodeID
    var startPoint: CGPoint
    var endPoint: CGPoint
    var clusterID: UUID?
    var layerId: UUID? = nil
    var lineWidth: CGFloat = 1.0

    func makeDrawingPrimitives(in context: RenderContext) -> [LayeredDrawingPrimitive] {
        let path = CGMutablePath()
        path.move(to: startPoint)
        path.addLine(to: endPoint)
        let primitive = DrawingPrimitive.stroke(
            path: path,
            color: NSColor.controlAccentColor.cgColor,
            lineWidth: lineWidth,
            lineCap: .round
        )
        return [LayeredDrawingPrimitive(primitive, layerId: layerId)]
    }

    func haloPath() -> CGPath? {
        let path = CGMutablePath()
        path.move(to: startPoint)
        path.addLine(to: endPoint)
        return path
    }

    func hitTest(point: CGPoint, tolerance: CGFloat) -> Bool {
        let padding = tolerance + (lineWidth / 2)
        let minX = min(startPoint.x, endPoint.x) - padding
        let maxX = max(startPoint.x, endPoint.x) + padding
        let minY = min(startPoint.y, endPoint.y) - padding
        let maxY = max(startPoint.y, endPoint.y) + padding

        guard point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY else {
            return false
        }

        let dx = endPoint.x - startPoint.x
        let dy = endPoint.y - startPoint.y
        let epsilon: CGFloat = 1e-6
        if abs(dx) < epsilon { return abs(point.x - startPoint.x) < padding }
        if abs(dy) < epsilon { return abs(point.y - startPoint.y) < padding }

        let distance = abs(
            dy * point.x - dx * point.y + endPoint.y * startPoint.x - endPoint.x * startPoint.y
        ) / hypot(dx, dy)
        return distance < padding
    }

    var boundingBox: CGRect {
        CGRect(
            x: min(startPoint.x, endPoint.x),
            y: min(startPoint.y, endPoint.y),
            width: abs(startPoint.x - endPoint.x),
            height: abs(startPoint.y - endPoint.y)
        )
    }

    var hitTestPriority: Int { 0 }
}
