//
//  HandlesView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 12.07.25.
//

import AppKit

final class HandlesView: NSView {

    var elements: [CanvasElement] = [] {
        didSet { rebuildPath() }
    }
    var selectedIDs: Set<UUID> = [] {
        didSet { rebuildPath() }
    }
    var magnification: CGFloat = 1.0 {
        didSet { rebuildPath() }
    }

    private let shapeLayer = CAShapeLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        layer?.isGeometryFlipped = true
        shapeLayer.fillColor = NSColor.white.cgColor
        shapeLayer.strokeColor = NSColor.systemBlue.cgColor
        layer?.addSublayer(shapeLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isOpaque: Bool { false }

    override func layout() {
        super.layout()
        shapeLayer.frame = bounds
        rebuildPath()
    }

    private func rebuildPath() {
        guard selectedIDs.count == 1 else {
            shapeLayer.path = nil
            return
        }

        let scale = 1 / max(magnification, 0.01)
        let size: CGFloat = 10 * scale
        let half = size / 2
        let path = CGMutablePath()

        for element in elements where selectedIDs.contains(element.id) && element.isPrimitiveEditable {
            for handle in element.handles() {
                path.addEllipse(in: CGRect(
                    x: handle.position.x - half,
                    y: handle.position.y - half,
                    width: size,
                    height: size
                ))
            }
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shapeLayer.lineWidth = scale
        shapeLayer.path = path
        CATransaction.commit()
    }
}
