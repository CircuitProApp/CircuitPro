//
//  CanvasRectangle.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 21.06.25.
//

import AppKit

struct CanvasRectangle: CanvasPrimitive {

    let id: UUID
    var size: CGSize
    var cornerRadius: CGFloat
    var position: CGPoint
    var rotation: CGFloat
    var strokeWidth: CGFloat
    var filled: Bool
    var color: SDColor?

    var layerId: UUID?

    func makePath() -> CGPath {
        // Create the rect centered at the origin, not at self.position.
        let frame = CGRect(
            x: -size.width * 0.5,
            y: -size.height * 0.5,
            width: size.width,
            height: size.height
        )

        let path = CGMutablePath()
        let clampedCornerRadius = max(0, min(cornerRadius, min(size.width, size.height) * 0.5))
        path.addRoundedRect(in: frame, cornerWidth: clampedCornerRadius, cornerHeight: clampedCornerRadius)

        return path
    }
}

extension CanvasRectangle: CanvasItem {}

extension CanvasRectangle {
    var maximumCornerRadius: CGFloat {
        min(size.width, size.height) / 2
    }
}
