import AppKit

class PreviewRenderLayer: RenderLayer {
    var layerKey: String = "preview"
    
    // A persistent container layer for all preview shapes.
    private let rootLayer = CALayer()
    
    // The pool of reusable shape layers.
    private var shapeLayerPool: [CAShapeLayer] = []

    /// **NEW:** Called once to install the root container layer.
    func install(on hostLayer: CALayer) {
        hostLayer.addSublayer(rootLayer)
    }

    /// **NEW:** Updates the preview by reusing, creating, and hiding layers from a pool.
    func update(using context: RenderContext) {
        // 1. Get the drawing parameters from the active tool.
        guard var tool = context.selectedTool,
              tool.id != "cursor",
              let mouse = context.mouseLocation
        else {
            // If no tool is active, hide all layers in the pool and exit.
            hideAllLayers()
            return
        }
        
        let drawingParams = tool.preview(mouse: mouse, context: context)
        
        // If the tool returns no preview shapes, hide all layers.
        guard !drawingParams.isEmpty else {
            hideAllLayers()
            return
        }

        // 2. Use the layer pooling strategy to draw the shapes.
        for (index, params) in drawingParams.enumerated() {
            // Get a layer from the pool (or create a new one if needed).
            let shapeLayer = layer(at: index)
            // Configure it with the new parameters.
            configure(layer: shapeLayer, from: params)
        }
        
        // 3. Hide any remaining, unused layers in the pool.
        if drawingParams.count < shapeLayerPool.count {
            for i in drawingParams.count..<shapeLayerPool.count {
                shapeLayerPool[i].isHidden = true
            }
        }
    }
    
    /// Previews are purely visual and should not be interactive.
    func hitTest(point: CGPoint, context: RenderContext) -> CanvasHitTarget? {
        return nil
    }

    // MARK: - Layer Pooling Helpers
    
    /// Hides all layers currently in the pool.
    private func hideAllLayers() {
        for layer in shapeLayerPool {
            layer.isHidden = true
        }
    }

    /// Retrieves a layer from the pool at a specific index. If the pool is not large enough,
    /// it creates a new layer, adds it to the pool and the scene, and returns it.
    private func layer(at index: Int) -> CAShapeLayer {
        if index < shapeLayerPool.count {
            // Success: Reuse an existing layer.
            let layer = shapeLayerPool[index]
            layer.isHidden = false // Make sure it's visible.
            return layer
        }
        
        // Failure: Pool exhausted. Create a new layer.
        let newLayer = CAShapeLayer()
        shapeLayerPool.append(newLayer)
        rootLayer.addSublayer(newLayer)
        return newLayer
    }
    
    /// Applies a set of drawing parameters to a given layer.
    private func configure(layer: CAShapeLayer, from parameters: DrawingParameters) {
        layer.path = parameters.path
        layer.fillColor = parameters.fillColor
        layer.strokeColor = parameters.strokeColor
        layer.lineWidth = parameters.lineWidth // Not scaled down by magnification for previews.
        layer.lineDashPattern = parameters.lineDashPattern
        layer.lineCap = parameters.lineCap
        layer.lineJoin = parameters.lineJoin
        layer.fillRule = parameters.fillRule
    }
}
