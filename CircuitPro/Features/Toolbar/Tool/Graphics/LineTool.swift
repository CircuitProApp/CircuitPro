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
        if let start = self.start {
            defer { self.start = nil }
            let line = LinePrimitive(
                id: UUID(),
                start: start,
                end: location,
                strokeWidth: 1, // This is the persistent model stroke width
                color: .init(color: context.selectedLayer.color)
            )
            return .element(.primitive(.line(line)))
        } else {
            self.start = location
            return .noResult
        }
    }

    mutating func preview(mouse: CGPoint, context: CanvasToolContext) -> [DrawingParameters] {
        guard let start else { return [] }

        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: mouse)

        return [DrawingParameters(
            path: path,
            lineWidth: 1.0,
            fillColor: nil,
            strokeColor: NSColor(context.selectedLayer.color).cgColor,
            lineDashPattern: [4, 4]
        )]
    }

    mutating func handleEscape() {
        start = nil
    }

    mutating func handleBackspace() {
        start = nil
    }
}
