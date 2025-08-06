import AppKit

class PreviewRenderLayer: RenderLayer {
    
    // A persistent container layer for all preview shapes.
    private let rootLayer = CALayer()
    
    // The pool of reusable shape layers.
    private var shapeLayerPool: [CAShapeLayer] = []

    func install(on hostLayer: CALayer) {
        hostLayer.addSublayer(rootLayer)
    }

    func update(using context: RenderContext) {
        guard let tool = context.selectedTool,
              !(tool is CursorTool),
              let mouseLocation = context.processedMouseLocation
        else {
            // If no tool is active, or it's the cursor, or the mouse is not
            // on the canvas, hide all preview layers and exit.
            hideAllLayers()
            return
        }

        
        // Pass the *snapped* location to the tool's preview method.
        let drawingParams = tool.preview(mouse: mouseLocation, context: context)

        
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
