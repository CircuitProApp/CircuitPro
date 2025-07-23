//
//  MarqueeView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 14.06.25.
//

import AppKit

/// Vector-based selection marquee that draws a dashed rectangle.
final class MarqueeView: CanvasOverlayView {

    // MARK: - API
    
    /// Selection rectangle in view coordinates (y-down).
    /// The overlay is hidden if this is `nil`.
    var rect: CGRect? {
        didSet {
            guard rect != oldValue else { return }
            updateDrawing()
        }
    }

    // MARK: - Drawing

    /// Provides the drawing data for the selection marquee.
    override func makeDrawingParameters() -> DrawingParameters? {
        // 1. Check for a valid rectangle
        guard let rect else { return nil }

        // 2. Create the path from the rectangle
        let path = CGPath(rect: rect, transform: nil)

        // 3. Configure drawing parameters
        let fillColor = NSColor.systemBlue.withAlphaComponent(0.1).cgColor
        let strokeColor = NSColor.systemBlue.cgColor
        let dashPattern: [NSNumber] = [4, 2]

        // 4. Return parameters
        // The lineWidth is set to a base of 1.0; the superclass will scale it
        // correctly based on the current magnification level.
        return DrawingParameters(
            path: path,
            lineWidth: 1.0,
            fillColor: fillColor,
            strokeColor: strokeColor,
            lineDashPattern: dashPattern,
            lineCap: .butt,
            lineJoin: .miter
        )
    }
}
