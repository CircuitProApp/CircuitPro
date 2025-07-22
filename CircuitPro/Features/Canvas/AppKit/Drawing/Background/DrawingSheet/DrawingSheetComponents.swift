//
//  DrawingSheetComponents.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 19.06.25.
//

import AppKit

// MARK: - DrawingMetrics
struct DrawingMetrics {
    let outerBounds: CGRect
    let innerBounds: CGRect
    let titleBlockFrame: CGRect
    let horizontalTickSpacing: CGFloat
    let verticalTickSpacing: CGFloat

    init(viewBounds: CGRect, inset: CGFloat, horizontalTickSpacing: CGFloat, verticalTickSpacing: CGFloat, cellHeight: CGFloat, cellValues: [String: String]) {
        self.outerBounds = viewBounds.insetBy(dx: 0.5, dy: 0.5)
        self.innerBounds = outerBounds.insetBy(dx: inset, dy: inset)
        self.horizontalTickSpacing = horizontalTickSpacing
        self.verticalTickSpacing = verticalTickSpacing

        let rowCount = cellValues.count
        let blockWidth = cellHeight * 8
        let blockHeight = CGFloat(rowCount) * cellHeight
        
        // 1. Calculate the title block frame from the bottom-right corner.
        // In a non-flipped coordinate system, the origin is at the bottom-left.
        // We use innerBounds.minY as the base for the y-coordinate.
        self.titleBlockFrame = CGRect(
            x: innerBounds.maxX - blockWidth,
            y: innerBounds.minY,
            width: blockWidth,
            height: blockHeight
        )
    }
}

// MARK: - BorderDrawer
struct BorderDrawer {
    func draw(in context: CGContext, metrics: DrawingMetrics) {
        context.stroke(metrics.outerBounds)
        context.stroke(metrics.innerBounds)
    }
}

// MARK: - RulerDrawer
struct RulerDrawer {
    enum Position {
        case top, bottom, left, right
    }

    let position: Position
    let graphicColor: NSColor
    let safeFont: (CGFloat, NSFont.Weight) -> NSFont
    let showLabels: Bool

    private func attrs(font: NSFont) -> [NSAttributedString.Key: Any] {
        [.font: font, .foregroundColor: graphicColor]
    }

    private func labelForIndex(_ index: Int, isNumber: Bool) -> String {
        if isNumber { return "\(index + 1)" }
        var number = index
        var label = ""
        repeat {
            let remainder = number % 26
            label = String(UnicodeScalar(65 + remainder)!) + label
            number = number / 26 - 1
        } while number >= 0
        return label
    }

    func draw(in context: CGContext, metrics: DrawingMetrics) {
        switch position {
        case .top:
            drawRuler(context, inner: metrics.innerBounds, outer: metrics.outerBounds, tickSpacing: metrics.horizontalTickSpacing, isVertical: false, isPrimaryEdge: true)
        case .bottom:
            drawRuler(context, inner: metrics.innerBounds, outer: metrics.outerBounds, tickSpacing: metrics.horizontalTickSpacing, isVertical: false, isPrimaryEdge: false)
        case .left:
            drawRuler(context, inner: metrics.innerBounds, outer: metrics.outerBounds, tickSpacing: metrics.verticalTickSpacing, isVertical: true, isPrimaryEdge: true)
        case .right:
            drawRuler(context, inner: metrics.innerBounds, outer: metrics.outerBounds, tickSpacing: metrics.verticalTickSpacing, isVertical: true, isPrimaryEdge: false)
        }
    }

    private func drawRuler(_ ctx: CGContext, inner: CGRect, outer: CGRect, tickSpacing: CGFloat, isVertical: Bool, isPrimaryEdge: Bool) {
        guard tickSpacing > 0 else { return }
        let font = safeFont(9, .regular)
        let attr = attrs(font: font)

        if isVertical {
            let xTick = isPrimaryEdge ? inner.minX : inner.maxX
            let xLabel = isPrimaryEdge ? (inner.minX + outer.minX) * 0.5 : (inner.maxX + outer.maxX) * 0.5
            let yRange = stride(from: inner.minY + tickSpacing, to: inner.maxY, by: tickSpacing)
            
            let totalVerticalIntervals = Int(floor(inner.height / tickSpacing))

            for (i, y) in yRange.enumerated() {
                ctx.move(to: .init(x: xTick, y: y))
                ctx.addLine(to: .init(x: isPrimaryEdge ? outer.minX : outer.maxX, y: y))
                ctx.strokePath()

                if showLabels {
                    let prevY = y - tickSpacing
                    let mid = (y + prevY) * 0.5
                    
                    let labelIndexFromTop = totalVerticalIntervals - 1 - i
                    let text = labelForIndex(labelIndexFromTop, isNumber: false) as NSString
                    
                    let size = text.size(withAttributes: attr)
                    text.draw(at: .init(x: xLabel - size.width * 0.5, y: mid - size.height * 0.5), withAttributes: attr)
                }
            }
        } else { // Horizontal
            let yTick = isPrimaryEdge ? inner.minY : inner.maxY
            let yLabel = isPrimaryEdge ? (inner.minY + outer.minY) * 0.5 : (inner.maxY + outer.maxY) * 0.5
            let xRange = stride(from: inner.minX + tickSpacing, to: inner.maxX, by: tickSpacing)

            for (i, x) in xRange.enumerated() {
                ctx.move(to: .init(x: x, y: yTick))
                ctx.addLine(to: .init(x: x, y: isPrimaryEdge ? outer.minY : outer.maxY))
                ctx.strokePath()

                if showLabels {
                    let prevX = x - tickSpacing
                    let mid = (x + prevX) * 0.5
                    let text = labelForIndex(i, isNumber: true) as NSString
                    let size = text.size(withAttributes: attr)
                    text.draw(at: .init(x: mid - size.width * 0.5, y: yLabel - size.height * 0.5), withAttributes: attr)
                }
            }
        }
    }
}

// MARK: - TitleBlockDrawer
struct TitleBlockDrawer {
    let cellValues: [String: String]
    let graphicColor: NSColor
    let cellPad: CGFloat
    let cellHeight: CGFloat
    let safeFont: (CGFloat, NSFont.Weight) -> NSFont

    private func attrs(font: NSFont) -> [NSAttributedString.Key: Any] {
        [.font: font, .foregroundColor: graphicColor]
    }

    func draw(in context: CGContext, metrics: DrawingMetrics) {
        let rect = metrics.titleBlockFrame
        context.stroke(rect)

        for rowIndex in 1..<cellValues.count {
            let y = rect.minY + CGFloat(rowIndex) * cellHeight
            context.move(to: CGPoint(x: rect.minX, y: y))
            context.addLine(to: CGPoint(x: rect.maxX, y: y))
            context.strokePath()
        }

        let keyFont = safeFont(8, .semibold)
        let valueFont = safeFont(11, .regular)
        let keyAttributes = attrs(font: keyFont)
        let valueAttributes = attrs(font: valueFont)

        for (row, keyValue) in cellValues.enumerated() {
            let y = rect.minY + CGFloat(row) * cellHeight
            let cell = CGRect(x: rect.minX, y: y, width: rect.width, height: cellHeight)
                .insetBy(dx: cellPad, dy: 0)

            (keyValue.key.uppercased() as NSString)
                .draw(at: CGPoint(x: cell.minX, y: cell.minY + 2), withAttributes: keyAttributes)

            let value = keyValue.value as NSString
            let valueSize = value.size(withAttributes: valueAttributes)
            value.draw(
                at: CGPoint(
                    x: cell.maxX - valueSize.width,
                    y: cell.minY + (cell.height - valueSize.height) * 0.5
                ),
                withAttributes: valueAttributes
            )
        }
    }
}
