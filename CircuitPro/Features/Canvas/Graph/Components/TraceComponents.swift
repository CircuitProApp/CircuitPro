//
//  TraceComponents.swift
//  CircuitPro
//
//  Created by Codex on 9/22/25.
//

import AppKit
import Foundation

struct TraceVertexComponent: GraphComponent {
    var point: CGPoint
}

struct TraceEdgeComponent: GraphComponent, LayeredDrawable, HitTestable, HaloProviding, Bounded, HitTestPriorityProviding {
    let id: UUID
    var start: NodeID
    var end: NodeID
    var startPoint: CGPoint
    var endPoint: CGPoint
    var width: CGFloat
    var layerId: UUID?

    func primitivesByLayer(in context: RenderContext) -> [UUID?: [DrawingPrimitive]] {
        let path = CGMutablePath()
        path.move(to: startPoint)
        path.addLine(to: endPoint)

        let color = resolveColor(in: context)
        let primitive = DrawingPrimitive.stroke(
            path: path,
            color: color,
            lineWidth: width,
            lineCap: .round
        )

        return [layerId: [primitive]]
    }

    func haloPath() -> CGPath? {
        let path = CGMutablePath()
        path.move(to: startPoint)
        path.addLine(to: endPoint)
        return path
    }

    func hitTest(point: CGPoint, tolerance: CGFloat) -> Bool {
        let padding = tolerance + (width / 2)
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

    var hitTestPriority: Int { 1 }

    private func resolveColor(in context: RenderContext) -> CGColor {
        if let layerId,
           let layer = context.layers.first(where: { $0.id == layerId }) {
            return layer.color
        }
        return NSColor.systemBlue.cgColor
    }
}
