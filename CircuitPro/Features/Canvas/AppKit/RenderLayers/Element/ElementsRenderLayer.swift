import AppKit

class ElementsRenderLayer: RenderLayer {
    var layerKey: String = "elements"

    private let rootLayer = CALayer()
    private var layerPool: [CAShapeLayer] = []

    func install(on hostLayer: CALayer) {
        hostLayer.addSublayer(rootLayer)
    }

    /// Updates the element drawing by traversing the scene graph and using a layer pool.
    func update(using context: RenderContext) {
        let allSelectedIDs = context.selectedIDs.union(context.marqueeSelectedIDs)
        
        // 1. Recursively collect all drawing parameters from the scene graph.
        let allParams = collectDrawingParameters(from: context.sceneRoot, selectedIDs: allSelectedIDs)

        // 2. Use the layer pooling system to render the parameters.
        var currentLayerIndex = 0
        for params in allParams {
            let layer = layer(at: currentLayerIndex)
            configure(layer: layer, from: params)
            currentLayerIndex += 1
        }
        
        // 3. Hide any remaining, unused layers in the pool.
        if currentLayerIndex < layerPool.count {
            for i in currentLayerIndex..<layerPool.count {
                layerPool[i].isHidden = true
            }
        }
    }

    /// Recursively traverses the scene graph to gather all drawing and halo parameters.
    private func collectDrawingParameters(from node: any CanvasNode, selectedIDs: Set<UUID>) -> [DrawingParameters] {
        guard node.isVisible else { return [] }
        
        var allParameters: [DrawingParameters] = []

        // Get the selection halo for the current node *first*, so it's drawn behind.
        if let haloParams = node.makeHaloParameters(selectedIDs: selectedIDs) {
            allParameters.append(haloParams)
        }
        
        // Get the main body drawing parameters for the current node.
        allParameters.append(contentsOf: node.makeBodyParameters())

        // Recursively collect parameters from all children.
        for child in node.children {
            allParameters.append(contentsOf: collectDrawingParameters(from: child, selectedIDs: selectedIDs))
        }

        // Apply the node's world transform to all paths collected from it and its children.
        var transform = node.worldTransform
        if transform != .identity {
            for i in allParameters.indices {
                if let newPath = allParameters[i].path.copy(using: &transform) {
                    allParameters[i].path = newPath
                }
            }
        }
        
        return allParameters
    }

    // The hit-testing logic will be migrated later. For now, it does nothing.
    func hitTest(point: CGPoint, context: RenderContext) -> CanvasHitTarget? {
        // TODO: Migrate hit-testing to traverse the scene graph.
        return nil
    }

    // MARK: - Layer Pooling Helpers (Unchanged)
    
    private func layer(at index: Int) -> CAShapeLayer {
        if index < layerPool.count {
            let layer = layerPool[index]
            layer.isHidden = false
            return layer
        }
        let newLayer = CAShapeLayer()
        layerPool.append(newLayer)
        rootLayer.addSublayer(newLayer)
        return newLayer
    }
    
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
