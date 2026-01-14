//
//  CanvasRectangle.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 21.06.25.
//

import CoreGraphics
import Foundation

struct CanvasRectangle: CanvasPrimitive {

    let id: UUID
    var size: CGSize
    var cornerRadius: CGFloat
    var position: CGPoint
    var rotation: CGFloat
    var strokeWidth: CGFloat
    var filled: Bool

    var layerId: UUID?

}

extension CanvasRectangle: CanvasItem {}

extension CanvasRectangle {
    var maximumCornerRadius: CGFloat {
        min(size.width, size.height) / 2
    }
}
