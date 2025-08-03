import AppKit

class HandlesRenderLayer: RenderLayer {
    var layerKey: String = "handles"
    
    // 1. A single, persistent layer for drawing all handles.
    private let shapeLayer = CAShapeLayer()

    /// **NEW:** Called once to create the layer and add it to the host view's layer tree.
    func install(on hostLayer: CALayer) {
        // Configure constant properties that never change.
        shapeLayer.fillColor = NSColor.white.cgColor
        shapeLayer.strokeColor = NSColor.systemBlue.cgColor
        
        // Add the persistent layer to the host.
        hostLayer.addSublayer(shapeLayer)
    }

    /// **NEW:** Updates the properties of the existing layer on every redraw.
    func update(using context: RenderContext) {
        // First, determine if we should even draw handles.
        guard context.selectedIDs.count == 1,
              let element = context.elements.first(where: { context.selectedIDs.contains($0.id) && $0.isPrimitiveEditable }),
              !element.handles().isEmpty
        else {
            // If no valid element with handles is selected, hide the layer and clear its path.
            shapeLayer.isHidden = true
            shapeLayer.path = nil
            return
        }
        
        // If we get here, we need to draw handles. Ensure the layer is visible.
        shapeLayer.isHidden = false
        
        // Calculate the dynamic properties based on the context.
        let handles = element.handles()
        let path = CGMutablePath()
        let handleScreenSize: CGFloat = 10.0
        let sizeInModelCoordinates = handleScreenSize / max(context.magnification, .ulpOfOne)
        let half = sizeInModelCoordinates / 2.0

        for handle in handles {
            let handleRect = CGRect(
                x: handle.position.x - half,
                y: handle.position.y - half,
                width: sizeInModelCoordinates,
                height: sizeInModelCoordinates
            )
            path.addEllipse(in: handleRect)
        }

        // The line width must also be scaled to appear constant on screen.
        let lineWidth = 1.0 / max(context.magnification, .ulpOfOne)
        
        // Update the dynamic properties of our persistent layer.
        shapeLayer.path = path
        shapeLayer.lineWidth = lineWidth
    }
    
    /// Handles are not interactive via this layer; their interaction is managed
    /// by the `HandleDragGesture` which does its own spatial calculation.
    func hitTest(point: CGPoint, context: RenderContext) -> CanvasHitTarget? {
        return nil
    }
}
