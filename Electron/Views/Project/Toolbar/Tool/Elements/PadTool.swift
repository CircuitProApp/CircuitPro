//  PadTool.swift
//  Electron
//
//  Created by Giorgi Tchelidze on 5/16/25.
//

import SwiftUI

struct PadTool: CanvasTool {
    var id = "pad"
    var symbolName = AppIcons.pad
    var label = "Pad"

    mutating func handleTap(at location: CGPoint,
                            context: CanvasToolContext) -> CanvasElement? {
        let number = context.existingPadCount + 1
        let pad = Pad(
            number: number,
            position: location,
            shape: .rect(width: 5, height: 10),
            type: .surfaceMount,
            drillDiameter: nil
        )
        return .pad(pad)
    }

    mutating func drawPreview(in ctx: CGContext,
                              mouse: CGPoint,
                              context: CanvasToolContext)
    {
        let number = context.existingPadCount + 1
        let previewPad = Pad(
            number: number,
            position: mouse,
            shape: .rect(width: 5, height: 10),
            type: .surfaceMount,
            drillDiameter: nil
        )
        previewPad.draw(in: ctx, highlight: false)
    }
}
