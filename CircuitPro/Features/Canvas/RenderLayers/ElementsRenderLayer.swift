import AppKit

class ElementsRenderLayer: RenderLayer {

    private let rootLayer = CALayer()
    private var layerPool: [CAShapeLayer] = []

    func install(on hostLayer: CALayer) {
        hostLayer.addSublayer(rootLayer)
    }

    func update(using context: RenderContext) {
        var allParams: [DrawingParameters] = []
        collectParameters(from: context.sceneRoot, highlightedIDs: context.highlightedNodeIDs, finalParams: &allParams)

        var currentLayerIndex = 0
        for params in allParams {
            let layer = layer(at: currentLayerIndex)
            configure(layer: layer, from: params)
            currentLayerIndex += 1
        }
        
        if currentLayerIndex < layerPool.count {
            for i in currentLayerIndex..<layerPool.count {
                layerPool[i].isHidden = true
            }
        }
    }

    func hitTest(point: CGPoint, context: RenderContext) -> CanvasHitTarget? {
        let tolerance = 5.0 / max(context.magnification, .ulpOfOne)
        return context.sceneRoot.hitTest(point, tolerance: tolerance)
    }

    private func collectParameters(from node: any CanvasNode, highlightedIDs: Set<UUID>, finalParams: inout [DrawingParameters]) {
        guard node.isVisible else { return }

        var localParams: [DrawingParameters] = []
        
        // --- THIS IS THE FIX ---

        // Generate a halo if this node's ID is in the set to be highlighted...
        if highlightedIDs.contains(node.id) {
            
            // ...BUT: Do not generate a halo if our parent is ALSO highlighted.
            // This lets the parent draw a single composite halo for all its children.
            let isParentHighlighted = node.parent.flatMap { parentNode in
                highlightedIDs.contains(parentNode.id)
            } ?? false

            if !isParentHighlighted {
                // This node is the "root" of a highlight group, so it is responsible for drawing.
                if let haloParams = node.makeHaloParameters(selectedIDs: highlightedIDs) {
                    localParams.append(haloParams)
                }
            }
        }
        
        localParams.append(contentsOf: node.makeBodyParameters())

        if !localParams.isEmpty {
            var worldTransform = node.worldTransform
            for var param in localParams {
                if let worldPath = param.path.copy(using: &worldTransform) {
                    param.path = worldPath
                    finalParams.append(param)
                }
            }
        }

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
