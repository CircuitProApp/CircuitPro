//
//  DrawingSheetView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 19.06.25.
//

import AppKit

// MARK: - DrawingSheetView
final class DrawingSheetView: NSView {

    // MARK: Public Properties
    var sheetSize: PaperSize = .iso(.a4) { didSet { needsLayout = true } }
    var orientation: PaperOrientation = .landscape { didSet { needsLayout = true } }
    var rulerDivision: RulerDivision = .bySpacing(10) { didSet { needsLayout = true } }
    var showRulerLabels: Bool = true { didSet { needsLayout = true } }
    var cellValues: [String: String] = [:] { didSet { needsLayout = true } }

    // MARK: Private Properties
    private var managedLayers: [CALayer] = []
    private let graphicColor: NSColor = .black

    // MARK: Constants
    private let inset: CGFloat = 20
    private let cellHeight: CGFloat = 25
    private let cellPad: CGFloat = 10
    private let unitsPerMM: CGFloat = 10 // 10 canvas units == 1 mm

    // MARK: Initializers
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        // Set view layer to be transparent; backgrounds will be handled by dedicated layers.
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    // MARK: Layout and Drawing
    override func layout() {
        super.layout()
        updateLayers()
    }

    private func updateLayers() {
        // 1. Clear previous layers.
        managedLayers.forEach { $0.removeFromSuperlayer() }
        managedLayers.removeAll()

        // 2. Calculate metrics.
        let hSpacing: CGFloat, vSpacing: CGFloat
        let initialInnerBounds = bounds.insetBy(dx: inset, dy: inset)
        
        switch rulerDivision {
        case .byCount(let count):
            guard count > 0 else { return }
            hSpacing = initialInnerBounds.width / CGFloat(count)
            vSpacing = initialInnerBounds.height / CGFloat(count)
        case .bySpacing(let spacing):
            hSpacing = spacing * unitsPerMM
            vSpacing = spacing * unitsPerMM
        }
        
        let metrics = DrawingMetrics(
            viewBounds: bounds, inset: inset,
            horizontalTickSpacing: hSpacing, verticalTickSpacing: vSpacing,
            cellHeight: cellHeight, cellValues: cellValues
        )
        
        // 3. Create background layers.
        // These are added first to be at the bottom of the layer stack.
        createBackgroundLayers(metrics: metrics)
        
        // 4. Create and collect all foreground content layers.
        managedLayers.append(contentsOf: BorderDrawer().makeLayers(metrics: metrics, color: graphicColor.cgColor))

        if !cellValues.isEmpty {
            let drawer = TitleBlockDrawer(
                cellValues: cellValues, graphicColor: graphicColor, cellPad: cellPad,
                cellHeight: cellHeight, safeFont: safeFont
            )
            managedLayers.append(contentsOf: drawer.makeLayers(metrics: metrics))
        }
        
        let rulerPositions: [RulerDrawer.Position] = [.top, .bottom, .left, .right]
        rulerPositions.forEach { position in
            let drawer = RulerDrawer(position: position, graphicColor: graphicColor, safeFont: safeFont, showLabels: showRulerLabels)
            managedLayers.append(contentsOf: drawer.makeLayers(metrics: metrics))
        }
        
        // 5. Add all generated layers to the view's main layer.
        managedLayers.forEach { layer?.addSublayer($0) }
    }
    
    /// Creates and adds the background layers for the rulers and title block.
    private func createBackgroundLayers(metrics: DrawingMetrics) {
        // 1. Ruler Background
        // Create a path that fills the area between the outer and inner bounds
        // using the even-odd fill rule.
        let rulerBGPath = CGMutablePath()
        rulerBGPath.addRect(metrics.outerBounds)
        rulerBGPath.addRect(metrics.innerBounds)
        
        let rulerBGLayer = CAShapeLayer()
        rulerBGLayer.path = rulerBGPath
        rulerBGLayer.fillRule = .evenOdd
        rulerBGLayer.fillColor = NSColor.white.cgColor

        managedLayers.append(rulerBGLayer)
        
        // 2. Title Block Background
        // If there's a title block, create a separate background layer for it.
        if !cellValues.isEmpty {
            let titleBGPath = CGPath(rect: metrics.titleBlockFrame, transform: nil)
            let titleBGLayer = CAShapeLayer()
            titleBGLayer.path = titleBGPath
            titleBGLayer.fillColor = NSColor.white.cgColor
            managedLayers.append(titleBGLayer)
        }
    }

    // MARK: Sizing
    override var intrinsicContentSize: NSSize {
        sheetSize.canvasSize(scale: unitsPerMM, orientation: orientation)
    }
    
    // MARK: Helpers
    fileprivate func safeFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        NSFont.monospacedSystemFont(ofSize: size, weight: weight) ?? NSFont.systemFont(ofSize: size, weight: weight)
    }
}
