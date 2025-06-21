//
//  CanvasTool.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/30/25.
//

import SwiftUI

protocol CanvasTool: Hashable {
    var id: String { get }
    var symbolName: String { get }
    var label: String { get }

    mutating func handleTap(at location: CGPoint, context: CanvasToolContext) -> CanvasElement?

    mutating func drawPreview(in ctx: CGContext, mouse: CGPoint, context: CanvasToolContext)
}

extension CanvasTool {
    mutating func handleTap(at location: CGPoint) -> CanvasElement? {
        handleTap(at: location, context: CanvasToolContext())
    }
}
