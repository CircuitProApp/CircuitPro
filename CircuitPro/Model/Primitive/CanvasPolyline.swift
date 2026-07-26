//
//  CanvasPolyline.swift
//  CircuitPro
//

import CoreGraphics
import Foundation

struct CanvasPolyline: CanvasPrimitive {

    let id: UUID
    var points: [CGPoint]
    var isClosed: Bool
    var position: CGPoint
    var rotation: CGFloat
    var strokeWidth: CGFloat
    var filled: Bool

    var layerId: UUID?

    init(
        id: UUID = UUID(),
        points: [CGPoint],
        isClosed: Bool = false,
        position: CGPoint,
        rotation: CGFloat = 0,
        strokeWidth: CGFloat,
        filled: Bool = false,
        layerId: UUID?
    ) {
        self.id = id
        self.points = points
        self.isClosed = isClosed
        self.position = position
        self.rotation = rotation
        self.strokeWidth = strokeWidth
        self.filled = filled
        self.layerId = layerId
    }
}

extension CanvasPolyline: CanvasItem {}
