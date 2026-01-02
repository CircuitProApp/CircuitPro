//
//  CanvasPad.swift
//  CircuitPro
//
//  Created by Codex on 9/22/25.
//

import AppKit
import CoreGraphics
import Foundation

struct CanvasPad: Drawable, Bounded, HitTestable, Layerable {
    var pad: Pad
    var ownerID: UUID?
    var ownerPosition: CGPoint
    var ownerRotation: CGFloat
    var layerId: UUID?
    var isSelectable: Bool

    var id: UUID {
        GraphPadID.makeID(ownerID: ownerID, padID: pad.id)
    }

    var hitTestPriority: Int { 2 }

    var boundingBox: CGRect {
        let localBounds = pad.calculateCompositePath().boundingBoxOfPath
        guard !localBounds.isNull else { return .null }
        return localBounds.applying(worldTransform)
    }

    func makeDrawingPrimitives(in context: RenderContext) -> [LayeredDrawingPrimitive] {
        let localPath = pad.calculateCompositePath()
        guard !localPath.isEmpty else { return [] }

        let color: CGColor
        if let layerId,
            let layer = context.layers.first(where: { $0.id == layerId })
        {
            color = layer.color
        } else {
            color = NSColor.systemRed.cgColor
        }

        let primitive = DrawingPrimitive.fill(path: localPath, color: color)
        var transform = worldTransform
        let worldPrimitive = primitive.applying(transform: &transform)
        return [LayeredDrawingPrimitive(worldPrimitive, layerId: layerId)]
    }

    func haloPath() -> CGPath? {
        let shapePath = pad.calculateShapePath()
        guard !shapePath.isEmpty else { return nil }
        let haloWidth: CGFloat = 1.0
        let thickOutline = shapePath.copy(
            strokingWithWidth: haloWidth * 2,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 1
        )
        let haloPath = thickOutline.union(shapePath)
        var transform = worldTransform
        return haloPath.copy(using: &transform)
    }

    func hitTest(point: CGPoint, tolerance: CGFloat) -> Bool {
        let localPoint = point.applying(worldTransform.inverted())
        let bodyPath = pad.calculateCompositePath()
        let hitArea = bodyPath.copy(
            strokingWithWidth: tolerance,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 1
        )
        return hitArea.contains(localPoint) || bodyPath.contains(localPoint)
    }
}

extension CanvasPad: Equatable {}

extension CanvasPad: CanvasItem {}

extension CanvasPad: ConnectionPoint {
    var position: CGPoint {
        CGPoint.zero.applying(worldTransform)
    }
}

extension CanvasPad: ConnectionPointProvider {
    var connectionPoints: [any ConnectionPoint] { [self] }
}

extension CanvasPad {
    var ownerTransform: CGAffineTransform {
        CGAffineTransform(translationX: ownerPosition.x, y: ownerPosition.y)
            .rotated(by: ownerRotation)
    }

    var worldTransform: CGAffineTransform {
        CGAffineTransform(translationX: pad.position.x, y: pad.position.y)
            .rotated(by: pad.rotation)
            .concatenating(ownerTransform)
    }
}
