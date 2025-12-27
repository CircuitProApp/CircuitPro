import AppKit

/// Renders the editing handles for a single selected graph primitive.
class HandlesRenderLayer: RenderLayer {

    private let shapeLayer = CAShapeLayer()

    func install(on hostLayer: CALayer) {
        // Configure constant properties that never change.
        shapeLayer.fillColor = NSColor.white.cgColor
        shapeLayer.strokeColor = NSColor.systemBlue.cgColor
        shapeLayer.zPosition = 1_000_000 // A high value to ensure handles appear on top of all other content.

        hostLayer.addSublayer(shapeLayer)
    }

    func update(using context: RenderContext) {
        // Attempt to find a single, selected, editable node.
        if let graphHandle = findGraphEditable(in: context) {
            render(handles: graphHandle.handles, transform: graphHandle.transform, context: context)
            return
        }
        shapeLayer.isHidden = true
        shapeLayer.path = nil
    }

    private func findGraphEditable(in context: RenderContext) -> (handles: [CanvasHandle], transform: CGAffineTransform)? {
        let graph = context.graph
        let selectionIDs = graph.selection
        guard selectionIDs.count == 1, let selectedID = selectionIDs.first else { return nil }
        guard let primitive = graph.component(AnyCanvasPrimitive.self, for: selectedID) else { return nil }

        let transform = CGAffineTransform(translationX: primitive.position.x, y: primitive.position.y)
            .rotated(by: primitive.rotation)
        return (primitive.handles(), transform)
    }

    private func render(handles: [CanvasHandle], transform: CGAffineTransform, context: RenderContext) {
        guard !handles.isEmpty else {
            shapeLayer.isHidden = true
            shapeLayer.path = nil
            return
        }

        // An editable node was found, so ensure the layer is visible.
        shapeLayer.isHidden = false

        let path = CGMutablePath()

        // Calculate handle size and line width based on canvas magnification
        // so they appear to have a constant size on screen.
        let handleScreenSize: CGFloat = 10.0
        let sizeInWorldCoords = handleScreenSize / max(context.magnification, .ulpOfOne)
        let half = sizeInWorldCoords / 2.0
        let lineWidth = 1.0 / max(context.magnification, .ulpOfOne)

        for handle in handles {
            // Convert the handle's local position to world coordinates.
            let worldHandlePosition = handle.position.applying(transform)

            let handleRect = CGRect(
                x: worldHandlePosition.x - half,
                y: worldHandlePosition.y - half,
                width: sizeInWorldCoords,
                height: sizeInWorldCoords
            )
            path.addEllipse(in: handleRect)
        }

        // Update the layer's path and line width.
        shapeLayer.path = path
        shapeLayer.lineWidth = lineWidth
    }
}
