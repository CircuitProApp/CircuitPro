//
//  HandlesView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 12.07.25.
//

import AppKit

final class HandlesView: NSView {
    
    var elements: [CanvasElement] = [] {
        didSet { needsDisplay = true }
    }
    var selectedIDs: Set<UUID> = [] {
        didSet { needsDisplay = true }
    }
    var magnification: CGFloat = 1.0 {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext, selectedIDs.count == 1 else { return }
        
        let scale = 1 / magnification
        ctx.setFillColor(NSColor(.white).cgColor)
        ctx.setStrokeColor(NSColor(.blue).cgColor)
        ctx.setLineWidth(1 * scale)

        let base: CGFloat = 10
        let size = base * scale
        let half = size / 2

        for element in elements where selectedIDs.contains(element.id) && element.isPrimitiveEditable {
            for handle in element.handles() {
                let radius = CGRect(
                    x: handle.position.x - half,
                    y: handle.position.y - half,
                    width: size,
                    height: size
                )
                ctx.fillEllipse(in: radius)
                ctx.strokeEllipse(in: radius)
            }
        }
    }
}
