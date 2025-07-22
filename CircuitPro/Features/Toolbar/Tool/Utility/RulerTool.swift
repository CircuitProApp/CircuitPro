//  RulerTool.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 5/18/25.

import SwiftUI

struct RulerTool: CanvasTool {

    let id: String = "ruler"
    let symbolName: String = CircuitProSymbols.Graphic.ruler
    let label: String = "Ruler"

    private var start: CGPoint?
    private var end: CGPoint?
    private var clicks: Int = 0

    mutating func handleTap(at location: CGPoint, context: CanvasToolContext) -> CanvasToolResult {
        switch clicks {
        case 0:
            start = location
            clicks = 1
        case 1:
            end = location
            clicks = 2
        case 2:
            start = location
            end = nil
            clicks = 1
        default:
            start = nil
            end = nil
            clicks = 0
        }

        return .noResult
    }

    // swiftlint:disable:next function_body_length
    mutating func preview(mouse: CGPoint, context: CanvasToolContext) -> ToolPreview? {
        guard let start = start else { return nil }
        let isDarkMode = NSAppearance.currentDrawing().bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let color: NSColor = .black

        let currentEnd = (clicks >= 2 ? end ?? mouse : mouse)

        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: currentEnd)

        let deltaX = currentEnd.x - start.x
        let deltaY = currentEnd.y - start.y
        // let distance = hypot(deltaX, deltaY)

        let mid = CGPoint(x: (start.x + currentEnd.x) / 2, y: (start.y + currentEnd.y) / 2)

        let rawPerp = CGPoint(x: -deltaY, y: deltaX)
        let length = hypot(rawPerp.x, rawPerp.y)
        guard length > 0 else {
            return ToolPreview(path: path, strokeColor: color.cgColor, lineWidth: 1.0)
        }
        let unitPerp = CGPoint(x: rawPerp.x / length, y: rawPerp.y / length)

        let tickLength: CGFloat = 4
        let drawTick: (CGPoint) -> Void = { center in
            let tickStart = CGPoint(x: center.x - unitPerp.x * tickLength, y: center.y - unitPerp.y * tickLength)
            let tickEnd = CGPoint(x: center.x + unitPerp.x * tickLength, y: center.y + unitPerp.y * tickLength)
            path.move(to: tickStart)
            path.addLine(to: tickEnd)
        }

        drawTick(mid)
        drawTick(start)
        drawTick(currentEnd)

        /*
        // Draw measurement label
        let distanceMM = distance / 10.0
        let labelText: String = distanceMM < 1
            ? String(format: "%.2f mm", distanceMM)
            : String(format: "%.1f mm", distanceMM)

        let fontSize: CGFloat = 12
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: color
        ]
        let text = NSAttributedString(string: labelText, attributes: attributes)
        let textSize = text.size()

        var labelOffsetDir = unitPerp
        if labelOffsetDir.y > 0 {
            labelOffsetDir = CGPoint(x: -labelOffsetDir.x, y: -labelOffsetDir.y)
        }

        let offsetDistance: CGFloat = 16
        let labelCenter = CGPoint(
            x: mid.x + labelOffsetDir.x * offsetDistance,
            y: mid.y + labelOffsetDir.y * offsetDistance
        )

        let drawPoint = CGPoint(
            x: labelCenter.x - textSize.width / 2,
            y: labelCenter.y - textSize.height / 2
        )

        let textLabel = ToolPreview.TextLabel(text: text, position: drawPoint, size: textSize)
        */
        return ToolPreview(path: path, strokeColor: color.cgColor, lineWidth: 1.0)
    }
    mutating func handleEscape() {
        start = nil
        end = nil
        clicks = 0
    }

    mutating func handleBackspace() {
        switch clicks {
        case 0:
            break
        case 1:
            start = nil
            clicks = 0
        case 2:
            end = nil
            clicks = 1
        default:
            start = nil
            end = nil
            clicks = 0
        }
    }


}
