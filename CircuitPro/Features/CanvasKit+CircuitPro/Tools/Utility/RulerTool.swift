////
////  RulerTool.swift
////  Circuit Pro
////
////  Created by Giorgi Tchelidze on 5/18/25.
////
//
//import SwiftUI
//import AppKit
//
//struct RulerTool: CanvasTool {
//
//    let id: String = "ruler"
//    let symbolName: String = CircuitProSymbols.Graphic.ruler
//    let label: String = "Ruler"
//
//    private var start: CGPoint?
//    private var end: CGPoint?
//    private var clicks: Int = 0
//
//    mutating func handleTap(at location: CGPoint, context: ToolInteractionContext) -> CanvasToolResult {
//        switch clicks {
//        case 0:
//            start = location
//            clicks = 1
//        case 1:
//            end = location
//            clicks = 2
//        case 2:
//            start = location
//            end = nil
//            clicks = 1
//        default:
//            start = nil
//            end = nil
//            clicks = 0
//        }
//
//        return .noResult
//    }
//
//    mutating func preview(mouse: CGPoint, context: RenderContext) -> [DrawingParameters] {
//        guard let start = start else { return [] }
//        let color: NSColor = .black
//
//        let currentEnd = (clicks == 2 ? end ?? mouse : mouse)
//        var allParameters: [DrawingParameters] = []
//
//        // 1. Create parameters for the stroked line and ticks.
//        let linePath = CGMutablePath()
//        linePath.move(to: start)
//        linePath.addLine(to: currentEnd)
//
//        let deltaX = currentEnd.x - start.x
//        let deltaY = currentEnd.y - start.y
//        let distance = hypot(deltaX, deltaY)
//
//        if distance > 0 {
//            let mid = CGPoint(x: (start.x + currentEnd.x) / 2, y: (start.y + currentEnd.y) / 2)
//            let rawPerp = CGPoint(x: -deltaY, y: deltaX)
//            let length = hypot(rawPerp.x, rawPerp.y)
//            let unitPerp = CGPoint(x: rawPerp.x / length, y: rawPerp.y / length)
//            let tickLength: CGFloat = 4
//
//            let drawTick: (CGPoint) -> Void = { center in
//                let tickStart = CGPoint(x: center.x - unitPerp.x * tickLength, y: center.y - unitPerp.y * tickLength)
//                let tickEnd = CGPoint(x: center.x + unitPerp.y * tickLength, y: center.y + unitPerp.y * tickLength)
//                linePath.move(to: tickStart)
//                linePath.addLine(to: tickEnd)
//            }
//            drawTick(mid)
//            drawTick(start)
//            drawTick(currentEnd)
//        }
//        
//        let lineParameters = DrawingParameters(path: linePath, lineWidth: 1.0, fillColor: nil, strokeColor: color.cgColor)
//        allParameters.append(lineParameters)
//        
//        // 2. Create SEPARATE parameters for the filled text label.
//        if distance > 0 {
//            let distanceInMM = distance / 10.0
//            let labelText = String(format: "%.2f mm", distanceInMM)
//            let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
//            
//            let textPath = TextUtilities.path(for: labelText, font: font)
//            let textBounds = textPath.boundingBoxOfPath
//
//            // Calculate position
//            let mid = CGPoint(x: (start.x + currentEnd.x) / 2, y: (start.y + currentEnd.y) / 2)
//            let unitPerp = CGPoint(x: -deltaY / distance, y: deltaX / distance)
//            var labelOffsetDir = unitPerp
//            if labelOffsetDir.y > 0 { labelOffsetDir = CGPoint(x: -labelOffsetDir.x, y: -labelOffsetDir.y) }
//            
//            let offsetDistance: CGFloat = 16
//            let labelCenter = CGPoint(x: mid.x + labelOffsetDir.x * offsetDistance, y: mid.y + labelOffsetDir.y * offsetDistance)
//            
//            var transform = CGAffineTransform(translationX: labelCenter.x - textBounds.midX, y: labelCenter.y - textBounds.midY)
//            
//            if let transformedTextPath = textPath.copy(using: &transform) {
//                let textParameters = DrawingParameters(
//                    path: transformedTextPath,
//                    lineWidth: 0,
//                    fillColor: color.cgColor,
//                    strokeColor: nil
//                )
//                allParameters.append(textParameters)
//            }
//        }
//        
//        return allParameters
//    }
//
//    mutating func handleEscape() -> Bool {
//        if clicks > 0 {
//            start = nil
//            end = nil
//            clicks = 0
//            return true
//        }
//        return false
//    }
//
//    mutating func handleBackspace() {
//        switch clicks {
//        case 0: break
//        case 1:
//            start = nil
//            clicks = 0
//        case 2:
//            end = nil
//            clicks = 1
//        default:
//            start = nil
//            end = nil
//            clicks = 0
//        }
//    }
//}
