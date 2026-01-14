//
//  CanvasCircle.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 21.06.25.
//

import AppKit

struct CanvasCircle: CanvasPrimitive {

    let id: UUID
    var radius: CGFloat
    var position: CGPoint
    var rotation: CGFloat
    var strokeWidth: CGFloat
    var color: SDColor?
    var filled: Bool

    var layerId: UUID?

    func makePath() -> CGPath {
        let path = CGMutablePath()

        // THE FIX: The center is now CGPoint.zero, not self.position.
        path.addArc(
            center: .zero,
            radius: radius,
            startAngle: 0,
            endAngle: .pi * 2,
            clockwise: false
        )

        return path
    }
}

extension CanvasCircle: CanvasItem {}
