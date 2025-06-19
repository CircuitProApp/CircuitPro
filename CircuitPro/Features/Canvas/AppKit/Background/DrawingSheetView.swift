//
//  DrawingSheetView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 19.06.25.
//

import AppKit

// MARK: - DrawingSheetView ---------------------------------------------------
final class DrawingSheetView: NSView {

    // Public knobs -----------------------------------------------------------
    var sheetSize:    PaperSize = .a4      { didSet { invalidate() } }
    var orientation:    PaperOrientation = .portrait { didSet { invalidate() } }
    
    private let graphicColor: NSColor = NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return .white
        } else {
            return .black
        }
    }
    
    var cellValues: [String: String] = [
        "Title": "Untitled",
        "Units": "mm",
        "Size":  PaperSize.a4.name.uppercased()
    ]                                      { didSet { invalidate() } }

    // Constants --------------------------------------------------------------
    private let inset:       CGFloat = 15
    private let tickSpacing: CGFloat = 100
    private let cellHeight:  CGFloat = 25
    private let cellPad:     CGFloat = 10
    private let unitsPerMM:  CGFloat = 10    // <── 10 canvas units == 1 mm

    // House-keeping ----------------------------------------------------------
    override var isFlipped: Bool { true }
    private func invalidate()    { needsDisplay = true }

    // Convenience ------------------------------------------------------------
    private func safeFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        NSFont.monospacedSystemFont(ofSize: size, weight: weight)
        ?? NSFont.systemFont(ofSize: size, weight: weight)
    }

    private func attrs(font: NSFont) -> [NSAttributedString.Key: Any] {
        [.font: font, .foregroundColor: graphicColor]
    }

    // MARK: Drawing ----------------------------------------------------------
    override func draw(_ dirtyRect: NSRect) {

        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setStrokeColor(graphicColor.cgColor)
        ctx.setLineWidth(1)

        // ------------------------------------------------------------------
        // 1. Sheet border (full paper size)
        // ------------------------------------------------------------------
        let outer = bounds
        ctx.stroke(outer)

        // ------------------------------------------------------------------
        // 2. Margin outline 85 units inside the sheet
        // ------------------------------------------------------------------
        let marginRect = outer.insetBy(dx: 100 - inset, dy: 100 - inset)
        ctx.stroke(marginRect)

        // ------------------------------------------------------------------
        // 3. Title-block (or content) outline inside the margin
        // ------------------------------------------------------------------
        let inner = marginRect.insetBy(dx: inset, dy: inset)
        ctx.stroke(inner)

        // ------------------------------------------------------------------
        // 4. Rulers and title block use the updated rectangles
        // ------------------------------------------------------------------
        drawHorizontalRuler(ctx, inner: inner, outer: marginRect, isTop: true)
        drawHorizontalRuler(ctx, inner: inner, outer: marginRect, isTop: false)
        drawVerticalRuler  (ctx, inner: inner, outer: marginRect, isLeft: true)
        drawVerticalRuler  (ctx, inner: inner, outer: marginRect, isLeft: false)

        drawTitleBlock(ctx, inner: inner)
    }
    
    private func labelForIndex(_ idx: Int, isNumber: Bool) -> String {
        if isNumber { return "\(idx + 1)" }

        // Spreadsheet-style lettering: A, B, …, Z, AA, AB, …
        var n = idx
        var s = ""
        repeat {
            let rem = n % 26
            s = String(UnicodeScalar(65 + rem)!) + s
            n = n / 26 - 1
        } while n >= 0
        return s
    }

    private func drawHorizontalRuler(_ ctx: CGContext,
                                     inner: CGRect,
                                     outer: CGRect,
                                     isTop: Bool) {

        let font = safeFont(size: 9, weight: .regular)
        let attr = attrs(font: font)

        let yTick = isTop ? inner.minY : inner.maxY
        let yLabel = isTop
            ? (inner.minY + outer.minY) * 0.5
            : (inner.maxY + outer.maxY) * 0.5

        for (i, x) in stride(from: inner.minX, through: inner.maxX, by: tickSpacing).enumerated() {

            ctx.move(to: .init(x: x, y: yTick))
            ctx.addLine(to: .init(x: x, y: isTop ? outer.minY : outer.maxY))
            ctx.strokePath()

            let nextX = min(x + tickSpacing, inner.maxX)
            let mid   = (x + nextX) * 0.5

            let text  = labelForIndex(i, isNumber: true) as NSString
            let size  = text.size(withAttributes: attr)
            text.draw(at: .init(x: mid - size.width * 0.5,
                                y: yLabel - size.height * 0.5),
                      withAttributes: attr)
        }
    }

    // MARK: – Vertical edges (letters)
    private func drawVerticalRuler(_ ctx: CGContext,
                                   inner: CGRect,
                                   outer: CGRect,
                                   isLeft: Bool) {

        let font = safeFont(size: 9, weight: .regular)
        let attr = attrs(font: font)

        let xTick = isLeft ? inner.minX : inner.maxX
        let xLabel = isLeft
            ? (inner.minX + outer.minX) * 0.5
            : (inner.maxX + outer.maxX) * 0.5

        for (i, y) in stride(from: inner.minY, through: inner.maxY, by: tickSpacing).enumerated() {

            ctx.move(to: .init(x: xTick, y: y))
            ctx.addLine(to: .init(x: isLeft ? outer.minX : outer.maxX, y: y))
            ctx.strokePath()

            let nextY = min(y + tickSpacing, inner.maxY)
            let mid   = (y + nextY) * 0.5

            let text  = labelForIndex(i, isNumber: false) as NSString
            let size  = text.size(withAttributes: attr)
            text.draw(at: .init(x: xLabel - size.width * 0.5,
                                y: mid - size.height * 0.5),
                      withAttributes: attr)
        }
    }

    private func drawTitleBlock(_ ctx: CGContext, inner: CGRect) {

        let rows        = cellValues.count
        let blockWidth  = cellHeight * 8
        let blockHeight = CGFloat(rows) * cellHeight
        let rect        = CGRect(x: inner.maxX - blockWidth,
                                 y: inner.maxY - blockHeight,
                                 width: blockWidth,
                                 height: blockHeight)

        ctx.stroke(rect)

        for r in 1..<rows {
            let y = rect.minY + CGFloat(r) * cellHeight
            ctx.move(to: .init(x: rect.minX, y: y))
            ctx.addLine(to: .init(x: rect.maxX, y: y))
            ctx.strokePath()
        }

        let keyFont   = safeFont(size: 8,  weight: .semibold)
        let valFont   = safeFont(size: 11, weight: .regular)
        let keyAttr   = attrs(font: keyFont)
        let valueAttr = attrs(font: valFont)

        for (row, kv) in cellValues.enumerated() {
            let y = rect.minY + CGFloat(row) * cellHeight
            let cell = CGRect(x: rect.minX, y: y, width: blockWidth, height: cellHeight)
                         .insetBy(dx: cellPad, dy: 0)

            (kv.key.uppercased() as NSString)
                .draw(at: CGPoint(x: cell.minX, y: cell.minY + 2), withAttributes: keyAttr)

            let value = kv.value as NSString
            let sz    = value.size(withAttributes: valueAttr)
            value.draw(at: CGPoint(x: cell.maxX - sz.width,
                                   y: cell.minY + (cell.height - sz.height) * 0.5),
                       withAttributes: valueAttr)
        }
    }

    // MARK: Intrinsic size (10 units == 1 mm)
    // replaces the old intrinsicContentSize
    override var intrinsicContentSize: NSSize {
        sheetSize.canvasSize(scale: 10, orientation: orientation)      // 10 canvas units = 1 mm
    }
}
