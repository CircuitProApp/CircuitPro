//
//  LineTool.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/30/25.
//
import SwiftUI

struct LineTool: CanvasTool {
    var id = "line"
    var symbolName = AppIcons.line
    var label = "Line"

    private var start: CGPoint?

    mutating func handleTap(at location: CGPoint, context: CanvasToolContext) -> CanvasElement? {
        if let start {
            defer { self.start = nil }
            let prim = LinePrimitive(
                uuid: UUID(),
                start: start,
                end: location,
                strokeWidth: 1,
                color: .init(color: context.selectedLayer.defaultColor)
            )
            return .primitive(.line(prim))
        } else {
            self.start = location
            return nil
        }
    }

    mutating func drawPreview(in ctx: CGContext, mouse: CGPoint, context: CanvasToolContext) {
        guard let start else { return }
        ctx.saveGState()
        ctx.setStrokeColor(NSColor(context.selectedLayer.defaultColor).cgColor)
        ctx.setLineWidth(1)
        ctx.setLineDash(phase: 0, lengths: [4])
        ctx.move(to: start)
        ctx.addLine(to: mouse)
        ctx.strokePath()
        ctx.restoreGState()
    }
}
