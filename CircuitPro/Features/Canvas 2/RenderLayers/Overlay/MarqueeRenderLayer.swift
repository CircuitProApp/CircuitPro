//import AppKit
//
//class MarqueeRenderLayer: RenderLayer {
//    var layerKey: String = "marquee"
//    
//    // 1. The layer is now a persistent property of the renderer.
//    private let shapeLayer = CAShapeLayer()
//
//    /// **NEW:** Called once to create the layer and add it to the host view's layer tree.
//    func install(on hostLayer: CALayer) {
//        // Set up constant properties that never change.
//        shapeLayer.fillColor = NSColor.systemBlue.withAlphaComponent(0.1).cgColor
//        shapeLayer.strokeColor = NSColor.systemBlue.cgColor
//        shapeLayer.lineCap = .butt
//        shapeLayer.lineJoin = .miter
//        
//        // Add the persistent layer to the host.
//        hostLayer.addSublayer(shapeLayer)
//    }
//
//    /// **NEW:** Updates the properties of the existing layer on every redraw.
//    func update(using context: RenderContext) {
//        // If a marquee rectangle exists in the context, draw it.
//        if let rect = context.marqueeRect {
//            // Make sure the layer is visible.
//            shapeLayer.isHidden = false
//
//            // Calculate dynamic properties from the context.
//            let scale = 1.0 / max(context.magnification, .ulpOfOne)
//            let path = CGPath(rect: rect, transform: nil)
//            let dashPattern: [NSNumber] = [4, 2]
//
//            // Update the dynamic properties of the existing layer.
//            shapeLayer.path = path
//            shapeLayer.lineWidth = 1.0 * scale
//            shapeLayer.lineDashPattern = dashPattern.map { NSNumber(value: $0.doubleValue * scale) }
//        } else {
//            // If there's no marquee, hide the layer. This is very cheap.
//            shapeLayer.isHidden = true
//            // Also clear the path to release any associated memory.
//            shapeLayer.path = nil
//        }
//    }
//    
//    /// The marquee is purely visual and should not be interactive.
//    func hitTest(point: CGPoint, context: RenderContext) -> CanvasHitTarget? {
//        return nil
//    }
//}
