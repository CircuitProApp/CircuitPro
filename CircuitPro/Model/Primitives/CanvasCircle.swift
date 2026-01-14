//
//  CanvasCircle.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 21.06.25.
//

import CoreGraphics
import Foundation

struct CanvasCircle: CanvasPrimitive {

    let id: UUID
    var radius: CGFloat
    var position: CGPoint
    var rotation: CGFloat
    var strokeWidth: CGFloat
    var filled: Bool

    var layerId: UUID?

}

extension CanvasCircle: CanvasItem {}
