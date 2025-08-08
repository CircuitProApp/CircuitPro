import AppKit

// MARK: - Elements Render Layer

class ElementsRenderLayer: RenderLayer {

    private let rootLayer = CALayer()
    private var shapeLayerPool: [CAShapeLayer] = []

    func install(on hostLayer: CALayer) {
        rootLayer.contentsScale = hostLayer.contentsScale
        hostLayer.addSublayer(rootLayer)
    }

    // MARK: - Update Cycle

    func update(using context: RenderContext) {
        // --- 1. Collect all HALO primitives with special grouping logic ---
        var haloPrimitives: [DrawingPrimitive] = []
        collectHaloPrimitives(from: context.sceneRoot, highlightedIDs: context.highlightedNodeIDs, finalPrimitives: &haloPrimitives)

        // --- 2. Collect all BODY primitives ---
        var bodyPrimitives: [DrawingPrimitive] = []
        collectBodyPrimitives(from: context.sceneRoot, finalPrimitives: &bodyPrimitives)

        // Combine the lists. Halos are drawn first, so they appear behind the bodies.
        let allPrimitives = haloPrimitives + bodyPrimitives

        // --- 3. Render all primitives using the layer pool ---
        var currentLayerIndex = 0
        for primitive in allPrimitives {
            let shapeLayer = layer(at: currentLayerIndex)
            switch primitive {
            case let .fill(path, color, rule):
                configure(layer: shapeLayer, forFill: path, color: color, rule: rule)

            case let .stroke(path, color, lineWidth, lineCap, lineJoin, miterLimit, lineDash):
                configure(layer: shapeLayer, forStroke: path, color: color, lineWidth: lineWidth, lineCap: lineCap, lineJoin: lineJoin, miterLimit: miterLimit, lineDash: lineDash)
            }
            currentLayerIndex += 1
        }
        
        // Hide any unused layers remaining in the pool.
        if currentLayerIndex < shapeLayerPool.count {
            for i in currentLayerIndex..<shapeLayerPool.count {
                shapeLayerPool[i].isHidden = true
            }
        }
    }

    // MARK: - Recursive Data Collection

    /// Recursively collects only the main "body" drawing primitives from the scene graph.
    private func collectBodyPrimitives(from node: BaseNode, finalPrimitives: inout [DrawingPrimitive]) {
        guard node.isVisible else { return }
        
        let localPrimitives = node.makeDrawingPrimitives()
        if !localPrimitives.isEmpty {
            var worldTransform = node.worldTransform
            for primitive in localPrimitives {
                finalPrimitives.append(primitive.applying(transform: &worldTransform))
            }
        }
        
        // Recurse to children.
        for child in node.children {
            collectBodyPrimitives(from: child, finalPrimitives: &finalPrimitives)
        }
    }

    /// Recursively collects halo primitives, with special grouping logic for certain container nodes.
    private func collectHaloPrimitives(from node: BaseNode, highlightedIDs: Set<UUID>, finalPrimitives: inout [DrawingPrimitive]) {
        guard node.isVisible else { return }

        // --- SPECIAL CASE: UNIFIED HALO FOR SCHEMATIC GRAPH NODE ---
        if let graphNode = node as? SchematicGraphNode {
            let selectedChildren = graphNode.children.filter { highlightedIDs.contains($0.id) }
            
            // If more than one child is selected, create a single unified halo.
            if !selectedChildren.isEmpty {
                let compositePath = CGMutablePath()
                for child in selectedChildren {
                    // WireNode's halo path is already in world coordinates, so no transform is needed.
                    if let childHaloPath = child.makeHaloPath() {
                        compositePath.addPath(childHaloPath)
                    }
                }
                
                if !compositePath.isEmpty {
                    finalPrimitives.append(haloPrimitive(for: compositePath))
                }
                // By returning here, we prevent individual halos from being drawn for these children.
                return
            }
        }
        
        // --- DEFAULT HALO LOGIC FOR ALL OTHER NODES ---
        // This runs if the node is not a handled group.
        let isHighlighted = highlightedIDs.contains(node.id)
        if isHighlighted {
            // Prevent drawing a halo if the parent is also drawing one (e.g. Pin inside a selected Symbol)
            let isParentHighlighted = node.parent.flatMap { highlightedIDs.contains($0.id) } ?? false
            
            if !isParentHighlighted, let haloPath = node.makeHaloPath() {
                var worldTransform = node.worldTransform
                if let worldPath = haloPath.copy(using: &worldTransform) {
                    finalPrimitives.append(haloPrimitive(for: worldPath))
                }
            }
        }
        
        // Recurse to children.
        for child in node.children {
            collectHaloPrimitives(from: child, highlightedIDs: highlightedIDs, finalPrimitives: &finalPrimitives)
        }
    }

    // MARK: - Hit Testing

    func hitTest(point: CGPoint, context: RenderContext) -> CanvasHitTarget? {
        let tolerance = 5.0 / max(context.magnification, .ulpOfOne)
        return context.sceneRoot.hitTest(point, tolerance: tolerance)
    }
    
    // MARK: - Layer Configuration & Helpers

    private func haloPrimitive(for path: CGPath) -> DrawingPrimitive {
        return .stroke(
            path: path,
            color: NSColor.systemBlue.withAlphaComponent(0.3).cgColor,
            lineWidth: 5.0, // A slightly thicker halo for groups
            lineCap: .round,
            lineJoin: .round
        )
    }
    
    private func configure(layer: CAShapeLayer, forFill path: CGPath, color: CGColor, rule: CAShapeLayerFillRule) {
        layer.path = path; layer.fillColor = color; layer.fillRule = rule; layer.strokeColor = nil; layer.lineWidth = 0
    }

    private func configure(layer: CAShapeLayer, forStroke path: CGPath, color: CGColor, lineWidth: CGFloat, lineCap: CAShapeLayerLineCap, lineJoin: CAShapeLayerLineJoin, miterLimit: CGFloat, lineDash: [NSNumber]?) {
        layer.path = path; layer.fillColor = nil; layer.strokeColor = color; layer.lineWidth = lineWidth; layer.lineCap = lineCap; layer.lineJoin = lineJoin; layer.miterLimit = miterLimit; layer.lineDashPattern = lineDash
    }
    
    private func layer(at index: Int) -> CAShapeLayer {
        if index < shapeLayerPool.count {
            shapeLayerPool[index].isHidden = false; return shapeLayerPool[index]
        }
        let newLayer = CAShapeLayer(); shapeLayerPool.append(newLayer); rootLayer.addSublayer(newLayer); return newLayer
    }
}
