import AppKit

/// A vector-based crosshairs overlay.
final class CrosshairsView: CanvasOverlayView {

    // MARK: - API
    
    /// The visual style of the crosshairs.
    /// The overlay is re-drawn when the style changes.
    var crosshairsStyle: CrosshairsStyle = .centeredCross {
        didSet {
            guard crosshairsStyle != oldValue else { return }
            updateDrawing()
        }
    }

    /// The center point for the crosshairs, specified in view coordinates (y-down).
    /// If `nil`, the crosshairs are not drawn.
    var location: CGPoint? {
        didSet {
            guard location != oldValue else { return }
            updateDrawing()
        }
    }

    // MARK: - Drawing

    /// Constructs the drawing parameters for the crosshairs path.
    override func makeDrawingParameters() -> DrawingParameters? {
        // 1. Validate state
        // Ensure the style is not hidden and a valid location is provided.
        guard crosshairsStyle != .hidden, let point = location else {
            return nil
        }

        // 2. Create path based on style
        let path = CGMutablePath()
        switch crosshairsStyle {
        case .fullScreenLines:
            // Create two lines that span the entire view bounds and intersect at the point.
            path.move(to: CGPoint(x: point.x, y: bounds.minY))
            path.addLine(to: CGPoint(x: point.x, y: bounds.maxY))
            path.move(to: CGPoint(x: bounds.minX, y: point.y))
            path.addLine(to: CGPoint(x: bounds.maxX, y: point.y))

        case .centeredCross:
            // Create a small cross shape centered at the point.
            let size: CGFloat = 20.0
            let half = size / 2.0
            path.move(to: CGPoint(x: point.x - half, y: point.y))
            path.addLine(to: CGPoint(x: point.x + half, y: point.y))
            path.move(to: CGPoint(x: point.x, y: point.y - half))
            path.addLine(to: CGPoint(x: point.x, y: point.y + half))

        case .hidden:
            // This case is handled by the initial guard.
            break
        }

        // 3. Return drawing parameters
        // The line width is set to a base of 1.0; the superclass will handle scaling.
        // There is no fill, only a stroke.
        return DrawingParameters(
            path: path,
            lineWidth: 1.0,
            fillColor: nil,
            strokeColor: NSColor.systemBlue.cgColor,
            lineCap: .round
        )
    }
}
