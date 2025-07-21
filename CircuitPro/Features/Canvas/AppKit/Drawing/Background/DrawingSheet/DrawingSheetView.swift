//
//  DrawingSheetView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 19.06.25.
//

import AppKit

// MARK: - DrawingSheetView ---------------------------------------------------
final class DrawingSheetView: NSView {

    enum RulerDivision {
        case byCount(Int)
        case bySpacing(CGFloat)
    }

    var sheetSize: PaperSize = .iso(.a4) { didSet { invalidate() } }
    var orientation: PaperOrientation = .landscape { didSet { invalidate() } }
    var rulerDivision: RulerDivision = .bySpacing(10) { didSet { invalidate() } }
    var showRulerLabels: Bool = true { didSet { invalidate() } }

    private let graphicColor: NSColor = NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return .black
        } else {
            return .black
        }
    }

    var cellValues: [String: String] = [:] { didSet { invalidate() } }

    // Constants --------------------------------------------------------------
    private let inset: CGFloat = 20
    private let cellHeight: CGFloat = 25
    private let cellPad: CGFloat = 10
    private let unitsPerMM: CGFloat = 10    // 10 canvas units == 1 mm

    // House-keeping ----------------------------------------------------------
    override var isFlipped: Bool { true }
    private func invalidate() { needsDisplay = true }

    // Convenience ------------------------------------------------------------
    fileprivate func safeFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        NSFont.monospacedSystemFont(ofSize: size, weight: weight)
        ?? NSFont.systemFont(ofSize: size, weight: weight)
    }

    // MARK: Drawing ----------------------------------------------------------
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        let initialMetrics = DrawingMetrics(viewBounds: bounds, inset: inset, horizontalTickSpacing: 0, verticalTickSpacing: 0, cellHeight: cellHeight, cellValues: cellValues)
        
        let hSpacing: CGFloat
        let vSpacing: CGFloat
        
        switch rulerDivision {
        case .byCount(let count):
            guard count > 0 else { return }
            hSpacing = initialMetrics.innerBounds.width / CGFloat(count)
            vSpacing = initialMetrics.innerBounds.height / CGFloat(count)
        case .bySpacing(let spacing):
            hSpacing = spacing * unitsPerMM
            vSpacing = spacing * unitsPerMM
        }
        
        let metrics = DrawingMetrics(
            viewBounds: bounds,
            inset: inset,
            horizontalTickSpacing: hSpacing,
            verticalTickSpacing: vSpacing,
            cellHeight: cellHeight,
            cellValues: cellValues
        )
        
        ctx.setLineWidth(1.0)
        ctx.setStrokeColor(graphicColor.cgColor)
        
        // Fill background for rulers and title block to avoid visual glitches
        ctx.saveGState()
        ctx.setFillColor(NSColor.white.cgColor)
        let topRulerBG = CGRect(x: metrics.outerBounds.minX, y: metrics.outerBounds.minY, width: metrics.outerBounds.width, height: metrics.innerBounds.minY - metrics.outerBounds.minY)
        let bottomRulerBG = CGRect(x: metrics.outerBounds.minX, y: metrics.innerBounds.maxY, width: metrics.outerBounds.width, height: metrics.outerBounds.maxY - metrics.innerBounds.maxY)
        let leftRulerBG = CGRect(x: metrics.outerBounds.minX, y: metrics.outerBounds.minY, width: metrics.innerBounds.minX - metrics.outerBounds.minX, height: metrics.outerBounds.height)
        let rightRulerBG = CGRect(x: metrics.innerBounds.maxX, y: metrics.outerBounds.minY, width: metrics.outerBounds.maxX - metrics.innerBounds.maxX, height: metrics.outerBounds.height)
        
        ctx.fill([topRulerBG, bottomRulerBG, leftRulerBG, rightRulerBG, metrics.titleBlockFrame])
        ctx.restoreGState()

        BorderDrawer().draw(in: ctx, metrics: metrics)
        
        if !cellValues.isEmpty {
            let titleDrawer = TitleBlockDrawer(
                cellValues: cellValues,
                graphicColor: graphicColor,
                cellPad: cellPad,
                cellHeight: cellHeight,
                safeFont: safeFont
            )
            titleDrawer.draw(in: ctx, metrics: metrics)
        }
        
        let rulerDrawerTop = RulerDrawer(position: .top, graphicColor: graphicColor, safeFont: safeFont, showLabels: showRulerLabels)
        rulerDrawerTop.draw(in: ctx, metrics: metrics)
        
        let rulerDrawerBottom = RulerDrawer(position: .bottom, graphicColor: graphicColor, safeFont: safeFont, showLabels: showRulerLabels)
        rulerDrawerBottom.draw(in: ctx, metrics: metrics)
        
        let rulerDrawerLeft = RulerDrawer(position: .left, graphicColor: graphicColor, safeFont: safeFont, showLabels: showRulerLabels)
        rulerDrawerLeft.draw(in: ctx, metrics: metrics)
        
        let rulerDrawerRight = RulerDrawer(position: .right, graphicColor: graphicColor, safeFont: safeFont, showLabels: showRulerLabels)
        rulerDrawerRight.draw(in: ctx, metrics: metrics)
    }

    // MARK: Intrinsic size (10 units == 1 mm)
    override var intrinsicContentSize: NSSize {
        sheetSize.canvasSize(scale: unitsPerMM, orientation: orientation)
    }
}
