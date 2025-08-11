import AppKit

class ElementsRenderLayer: RenderLayer {
    var layerKey: String = "elements"

    // 1. A persistent container for all element-related layers.
    private let rootLayer = CALayer()
    
    // 2. The pool of reusable shape layers.
    private var layerPool: [CAShapeLayer] = []

    /// **NEW:** Called once to install the root container layer.
    func install(on hostLayer: CALayer) {
        hostLayer.addSublayer(rootLayer)
    }

    /// **NEW:** Updates the element drawing by reusing, creating, and hiding layers from a pool.
    func update(using context: RenderContext) {
        var currentLayerIndex = 0
        let allSelectedIDs = context.selectedIDs.union(context.marqueeSelectedIDs)

        // Iterate through all elements that need to be drawn.
        for element in context.elements {
            
            // Draw the selection halo first (so it's rendered behind the body).
            if let haloParams = element.drawable.makeHaloParameters(selectedIDs: allSelectedIDs) {
                let haloLayer = layer(at: currentLayerIndex)
                configure(layer: haloLayer, from: haloParams)
                currentLayerIndex += 1
            }
            
            // Draw the element's body parts.
            for bodyParams in element.drawable.makeBodyParameters() {
                let bodyLayer = layer(at: currentLayerIndex)
                configure(layer: bodyLayer, from: bodyParams)
                currentLayerIndex += 1
            }
        }
        
        // Hide any remaining, unused layers in the pool. This is very cheap.
        if currentLayerIndex < layerPool.count {
            for i in currentLayerIndex..<layerPool.count {
                layerPool[i].isHidden = true
            }
        }
    }

    /// The hit-test logic remains the same, as it operates on the data model, not the layers.
    func hitTest(point: CGPoint, context: RenderContext) -> CanvasHitTarget? {
        let tolerance = 5.0 / context.magnification
        // Iterate elements in reverse to hit the top-most one first.
        for element in context.elements.reversed() {
            if let hit = element.hitTest(point, tolerance: tolerance) {
                return hit
            }
        }
        return nil
    }

    // MARK: - Layer Pooling Helpers

    /// Gets a layer from the pool, creating a new one if the pool is exhausted.
    private func layer(at index: Int) -> CAShapeLayer {
        if index < layerPool.count {
            // Success: An existing layer can be reused.
            let layer = layerPool[index]
            layer.isHidden = false // Ensure it's visible.
            return layer
        }
        
        // Failure: The pool is not large enough. Create a new layer.
        let newLayer = CAShapeLayer()
        layerPool.append(newLayer)
        rootLayer.addSublayer(newLayer)
        return newLayer
    }
    
    /// A simple helper to apply all drawing parameters to a given layer.
    private func configure(layer: CAShapeLayer, from parameters: DrawingParameters) {
        layer.path = parameters.path
        layer.fillColor = parameters.fillColor
        layer.strokeColor = parameters.strokeColor
        layer.lineWidth = parameters.lineWidth
        layer.lineCap = parameters.lineCap
        layer.lineJoin = parameters.lineJoin
        layer.lineDashPattern = parameters.lineDashPattern
        layer.fillRule = parameters.fillRule
    }
}
