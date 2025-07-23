import AppKit

/// An overlay that draws draggable handles for the selected element.
final class HandlesView: CanvasOverlayView {

    // MARK: - API

    /// The collection of all elements on the canvas.
    var elements: [CanvasElement] = [] {
        didSet { updateDrawing() }
    }

    /// The set of currently selected element IDs.
    /// Handles are only shown if a single element is selected.
    var selectedIDs: Set<UUID> = [] {
        didSet { updateDrawing() }
    }

    // MARK: - Drawing

    /// Creates the drawing parameters for the handles.
    override func makeDrawingParameters() -> DrawingParameters? {
        // 1. Validate State
        // Handles are only shown for a single selected, editable element.
        guard selectedIDs.count == 1,
              let element = elements.first(where: { selectedIDs.contains($0.id) && $0.isPrimitiveEditable })
        else {
            return nil
        }
        
        // 2. Get Handles
        let handles = element.handles()
        guard !handles.isEmpty else { return nil }

        // 3. Create Path
        // The handle size is scaled to remain constant on screen regardless of zoom.
        let path = CGMutablePath()
        let handleScreenSize: CGFloat = 10.0
        let sizeInViewCoordinates = handleScreenSize / max(magnification, .ulpOfOne)
        let half = sizeInViewCoordinates / 2.0

        for handle in handles {
            let handleRect = CGRect(
                x: handle.position.x - half,
                y: handle.position.y - half,
                width: sizeInViewCoordinates,
                height: sizeInViewCoordinates
            )
            path.addEllipse(in: handleRect)
        }

        // 4. Return Drawing Parameters
        // The base line width is 1.0; the superclass will scale it to ensure a
        // consistent 1-point stroke width on screen.
        return DrawingParameters(
            path: path,
            lineWidth: 1.0,
            fillColor: NSColor.white.cgColor,
            strokeColor: NSColor.systemBlue.cgColor
        )
    }
}
