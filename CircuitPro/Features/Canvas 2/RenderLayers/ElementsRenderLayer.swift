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
        var allParams: [DrawingParameters] = []
        // Kick off the recursive collection process, passing the final set of IDs to highlight.
        collectParameters(from: context.sceneRoot, highlightedIDs: context.highlightedNodeIDs, finalParams: &allParams)

        // Use the layer pooling system to render the collected parameters.
        var currentLayerIndex = 0
        for params in allParams {
            let layer = layer(at: currentLayerIndex)
            configure(layer: layer, from: params)
            currentLayerIndex += 1
        }
        
        // Hide any remaining, unused layers in the pool.
        if currentLayerIndex < layerPool.count {
            for i in currentLayerIndex..<layerPool.count {
                layerPool[i].isHidden = true
            }
        }
    }

    /// Performs a hit-test on the scene graph.
    func hitTest(point: CGPoint, context: RenderContext) -> CanvasHitTarget? {
        let tolerance = 5.0 / max(context.magnification, .ulpOfOne)
        // The layer's responsibility is to kick off the recursive hit-test on its data model.
        return context.sceneRoot.hitTest(point, tolerance: tolerance)
    }

    /// Recursively traverses the scene graph, collecting drawing parameters for each node,
    /// transforming them into world space, and adding them to a final flat array for rendering.
    /// - Parameters:
    ///   - node: The current `CanvasNode` to process.
    ///   - highlightedIDs: A `Set` of `UUID`s for all nodes that should be drawn with a halo.
    ///   - finalParams: An `inout` array where the final, world-transformed `DrawingParameters` are accumulated.
    private func collectParameters(from node: any CanvasNode, highlightedIDs: Set<UUID>, finalParams: inout [DrawingParameters]) {
        guard node.isVisible else { return }

        // Step 1: Get the parameters for THIS node, defined in its own LOCAL coordinate space.
        var localParams: [DrawingParameters] = []
        
        // Generate a halo if this node's ID is in the set to be highlighted.
        if highlightedIDs.contains(node.id) {
            // The default `makeHaloParameters` in `Drawable` works perfectly here.
             if let haloParams = node.makeHaloParameters(selectedIDs: highlightedIDs) {
                localParams.append(haloParams)
            }
        }
        
        // Get the main body shape.
        localParams.append(contentsOf: node.makeBodyParameters())

        // Step 2: Apply this node's final WORLD transform to its LOCAL parameters.
        if !localParams.isEmpty {
            var worldTransform = node.worldTransform
            for var param in localParams {
                if let worldPath = param.path.copy(using: &worldTransform) {
                    param.path = worldPath
                    finalParams.append(param)
                }
            }
        }

        // Step 3: Recurse for all children. THEY will be responsible for their own transforms in subsequent calls.
        for child in node.children {
            collectParameters(from: child, highlightedIDs: highlightedIDs, finalParams: &finalParams)
        }
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
