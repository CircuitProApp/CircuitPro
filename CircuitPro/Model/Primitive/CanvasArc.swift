//
//  CanvasArc.swift
//  CircuitPro
//

import CoreGraphics
import Foundation

struct CanvasArc: CanvasPrimitive {

    let id: UUID
    var radius: CGFloat
    var startAngle: CGFloat
    var endAngle: CGFloat
    var position: CGPoint
    var rotation: CGFloat
    var strokeWidth: CGFloat
    var filled: Bool

    var layerId: UUID?

    init(
        id: UUID = UUID(),
        radius: CGFloat,
        startAngle: CGFloat,
        endAngle: CGFloat,
        position: CGPoint,
        rotation: CGFloat = 0,
        strokeWidth: CGFloat,
        filled: Bool = false,
        layerId: UUID?
    ) {
        self.id = id
        self.radius = radius
        self.startAngle = startAngle
        self.endAngle = endAngle
        self.position = position
        self.rotation = rotation
        self.strokeWidth = strokeWidth
        self.filled = filled
        self.layerId = layerId
    }
}

extension CanvasArc: CanvasItem {}
