import AppKit

class PreviewRenderLayer: RenderLayer {
    var layerKey: String = "preview"
    
    // A persistent container layer for all preview shapes.
    private let rootLayer = CALayer()
    
    // The pool of reusable shape layers.
    private var shapeLayerPool: [CAShapeLayer] = []

    func install(on hostLayer: CALayer) {
        hostLayer.addSublayer(rootLayer)
    }

    func update(using context: RenderContext) {
        // --- THIS IS THE FIX ---
        // The check for `tool.id != "cursor"` is replaced with a type-safe check.
        // We also change `var tool` to `let tool` as class methods are not mutating.
        guard let tool = context.selectedTool,
              !(tool is CursorTool), // Only proceed if the tool is NOT the cursor.
              let mouse = context.mouseLocation
        else {
            // If no tool is active, or it's the cursor, or the mouse is not
            // on the canvas, hide all preview layers and exit.
            hideAllLayers()
            return
        }
        
        let drawingParams = tool.preview(mouse: mouse, context: context)
        
        // If the tool returns no preview shapes, hide all layers.
        guard !drawingParams.isEmpty else {
            hideAllLayers()
            return
        }

        // Use the layer pooling strategy to draw the shapes.
        for (index, params) in drawingParams.enumerated() {
            let shapeLayer = layer(at: index)
            configure(layer: shapeLayer, from: params)
        }
        
        // Hide any remaining, unused layers in the pool.
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
    
    private func hideAllLayers() {
        for layer in shapeLayerPool {
            layer.isHidden = true
        }
    }

    private func layer(at index: Int) -> CAShapeLayer {
        if index < shapeLayerPool.count {
            let layer = shapeLayerPool[index]
            layer.isHidden = false
            return layer
        }
        
        let newLayer = CAShapeLayer()
        shapeLayerPool.append(newLayer)
        rootLayer.addSublayer(newLayer)
        return newLayer
    }
    
    private func configure(layer: CAShapeLayer, from parameters: DrawingParameters) {
        layer.path = parameters.path
        layer.fillColor = parameters.fillColor
        layer.strokeColor = parameters.strokeColor
        layer.lineWidth = parameters.lineWidth
        layer.lineDashPattern = parameters.lineDashPattern
        layer.lineCap = parameters.lineCap
        layer.lineJoin = parameters.lineJoin
        layer.fillRule = parameters.fillRule
    }
}
