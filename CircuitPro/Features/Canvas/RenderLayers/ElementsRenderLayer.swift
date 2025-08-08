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
        var allPrimitives: [DrawingPrimitive] = []
        // We use a single, smarter recursive function to collect everything.
        collectPrimitives(from: context.sceneRoot, highlightedIDs: context.highlightedNodeIDs, finalPrimitives: &allPrimitives)

        // The rendering loop itself remains the same.
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
        
        if currentLayerIndex < shapeLayerPool.count {
            for i in currentLayerIndex..<shapeLayerPool.count {
                shapeLayerPool[i].isHidden = true
            }
        }
    }

    // MARK: - Recursive Data Collection (Corrected Logic)

    private func collectPrimitives(from node: BaseNode, highlightedIDs: Set<UUID>, finalPrimitives: inout [DrawingPrimitive]) {
        guard node.isVisible else { return }

        // --- 1. HALO GENERATION (with special grouping logic) ---
        var didHandleHaloForChildren = false

        // SPECIAL CASE: Unified halo for SchematicGraphNode
        if let graphNode = node as? SchematicGraphNode {
            let selectedChildren = graphNode.children.filter { highlightedIDs.contains($0.id) }
            if !selectedChildren.isEmpty {
                let compositePath = CGMutablePath()
                for child in selectedChildren {
                    if let childHaloPath = child.makeHaloPath() {
                        compositePath.addPath(childHaloPath)
                    }
                }
                if !compositePath.isEmpty {
                    finalPrimitives.append(haloPrimitive(for: compositePath))
                }
                // Mark that we've handled the halos for this group.
                didHandleHaloForChildren = true
            }
        }
        
        // DEFAULT CASE: For any other node that is itself highlighted
        if !didHandleHaloForChildren && highlightedIDs.contains(node.id) {
            let isParentGroupHandled = (node.parent as? SchematicGraphNode) != nil && didHandleHaloForChildren
            
            if !isParentGroupHandled, let haloPath = node.makeHaloPath() {
                var worldTransform = node.worldTransform
                if let worldPath = haloPath.copy(using: &worldTransform) {
                    finalPrimitives.append(haloPrimitive(for: worldPath))
                }
            }
        }

        // --- 2. BODY GENERATION ---
        // This is always done for every node.
        let localPrimitives = node.makeDrawingPrimitives()
        if !localPrimitives.isEmpty {
            var worldTransform = node.worldTransform
            for primitive in localPrimitives {
                finalPrimitives.append(primitive.applying(transform: &worldTransform))
            }
        }

        // --- 3. RECURSION ---
        // Always recurse into children. The logic within this function will handle
        // each child appropriately on the next call.
        for child in node.children {
            collectPrimitives(from: child, highlightedIDs: highlightedIDs, finalPrimitives: &finalPrimitives)
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
