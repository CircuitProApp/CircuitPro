//
//  CanvasToolContext.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 19.06.25.
//

import SwiftUI

struct CanvasToolContext {
    var existingPinCount: Int = 0
    var existingPadCount: Int = 0
    var selectedLayer: LayerKind = .copper
    var magnification: CGFloat = 1.0
    var hitSegmentID: UUID?
}
