//
//  GuideView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/23/25.
//

import AppKit

final class GuideView: NSView {

    // MARK: - Layers
    private let xAxisLayer = CAShapeLayer()
    private let yAxisLayer = CAShapeLayer()

    // MARK: - API
    var origin: CGPoint? {
        didSet {
            guard origin != oldValue else { return }
            updatePaths()
        }
    }
    
    var magnification: CGFloat = 1.0 {
        didSet {
            guard magnification != oldValue else { return }
            updatePaths()
        }
    }

    // MARK: - Init
    override init(frame: NSRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        // X-axis (Red)
        xAxisLayer.strokeColor = NSColor.systemRed.cgColor
        xAxisLayer.fillColor = nil
        
        // Y-axis (Green)
        yAxisLayer.strokeColor = NSColor.systemGreen.cgColor
        yAxisLayer.fillColor = nil

        layer?.addSublayer(xAxisLayer)
        layer?.addSublayer(yAxisLayer)
    }
    
    override func layout() {
        super.layout()
        updatePaths()
    }
    
    override func hitTest(_: NSPoint) -> NSView? { nil } // stay transparent

    private func updatePaths() {
        guard let origin = origin else {
            xAxisLayer.path = nil
            yAxisLayer.path = nil
            return
        }
        
        let lineWidth = 1.0 / max(magnification, .ulpOfOne)
        xAxisLayer.lineWidth = lineWidth
        yAxisLayer.lineWidth = lineWidth

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // X-axis path
        let xPath = CGMutablePath()
        xPath.move(to: CGPoint(x: bounds.minX, y: origin.y))
        xPath.addLine(to: CGPoint(x: bounds.maxX, y: origin.y))
        xAxisLayer.path = xPath

        // Y-axis path
        let yPath = CGMutablePath()
        yPath.move(to: CGPoint(x: origin.x, y: bounds.minY))
        yPath.addLine(to: CGPoint(x: origin.x, y: bounds.maxY))
        yAxisLayer.path = yPath

        CATransaction.commit()
    }
}
