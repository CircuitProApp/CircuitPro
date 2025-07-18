//
//  LineTool.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/30/25.
//
import SwiftUI

struct LineTool: CanvasTool {

    let id = "line"
    let symbolName = CircuitProSymbols.Graphic.line
    let label = "Line"

    private var start: CGPoint?

    mutating func handleTap(at location: CGPoint, context: CanvasToolContext) -> CanvasToolResult {
        if let start {
            defer { self.start = nil }
            let line = LinePrimitive(
                id: UUID(),
                start: start,
                end: location,
                rotation: 0,
                strokeWidth: 1,
                color: .init(color: context.selectedLayer.color)
            )
            return .element(.primitive(.line(line)))
        } else {
            self.start = location
            return .noResult
        }
    }

    mutating func drawPreview(in ctx: CGContext, mouse: CGPoint, context: CanvasToolContext) {
        guard let start else { return }
        ctx.saveGState()
        ctx.setStrokeColor(NSColor(context.selectedLayer.color).cgColor)
        ctx.setLineWidth(1)
        ctx.setLineDash(phase: 0, lengths: [4])
        ctx.move(to: start)
        ctx.addLine(to: mouse)
        ctx.strokePath()
        ctx.restoreGState()
    }

    mutating func handleEscape() {
        start = nil
    }

    mutating func handleBackspace() {
        start = nil
    }
}
