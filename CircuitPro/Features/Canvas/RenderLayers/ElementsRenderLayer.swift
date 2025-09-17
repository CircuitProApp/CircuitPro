// Features/Canvas/RenderLayers/ElementsRenderLayer.swift

import AppKit

/// Renders all canvas nodes and their selection halos, organizing them into a hierarchy
/// of CALayers that mirrors the `CanvasLayer` data model from the context.
final class ElementsRenderLayer: RenderLayer {

    private var backingLayers: [UUID: CALayer] = [:]
    private var defaultLayer: CALayer?
    private weak var hostLayer: CALayer?

    func install(on hostLayer: CALayer) {
        self.hostLayer = hostLayer
    }

    func update(using context: RenderContext) {
        guard let hostLayer = self.hostLayer else { return }

        // 1. Setup the CALayer hierarchy to match the data model.
        reconcileLayers(context: context, hostLayer: hostLayer)

        // 2. Clear all layers completely before redrawing.
        var allLayersToClear: [CALayer] = Array(backingLayers.values)
        if let defaultLayer = self.defaultLayer { allLayersToClear.append(defaultLayer) }
        allLayersToClear.forEach { $0.sublayers?.forEach { $0.removeFromSuperlayer() } }

        // 3. Get all nodes in the scene.
        let allNodes = context.sceneRoot.children.flatMap { flatten(node: $0) }
        
        // --- 4. GATHER ALL PRIMITIVES FIRST ---
        
        var bodyPrimitivesByLayer = gatherBodyPrimitives(from: allNodes, in: context)
        var haloPrimitivesByLayer = gatherHaloPrimitives(from: context, allNodes: allNodes)
        
        // --- 5. RENDER EVERYTHING ---
        
        // Merge the keys from both dictionaries to ensure we visit every layer that has content.
        let allLayerIDs = Set(bodyPrimitivesByLayer.keys).union(haloPrimitivesByLayer.keys)

        for layerID in allLayerIDs {
            let targetLayer: CALayer?
            if let layerID = layerID, let backingLayer = backingLayers[layerID] {
                targetLayer = backingLayer
            } else {
                targetLayer = getOrCreateDefaultLayer(on: hostLayer)
            }
            
            guard let renderLayer = targetLayer, !renderLayer.isHidden else { continue }
            
            // --- FIX: RENDER HALOS FIRST ---
            // By rendering halos before bodies, the bodies will be drawn on top,
            // correctly placing the halo "behind" the element.
            if let halos = haloPrimitivesByLayer[layerID] {
                render(primitives: halos, onto: renderLayer)
            }
            if let bodies = bodyPrimitivesByLayer[layerID] {
                render(primitives: bodies, onto: renderLayer)
            }
            // --- END FIX ---
        }
    }
    
    // MARK: - Primitive Gathering
    
    /// Collects and transforms all "body" drawing primitives from the scene, grouped by layer.
    private func gatherBodyPrimitives(from nodes: [BaseNode], in context: RenderContext) -> [UUID?: [DrawingPrimitive]] {
        var primitivesByLayer: [UUID?: [DrawingPrimitive]] = [:]

        for node in nodes where node.isVisible {
            var primitives: [DrawingPrimitive] = []
            
            if let primitiveNode = node as? PrimitiveNode {
                let resolvedColor = self.resolveColor(for: primitiveNode, in: context)
                primitives = primitiveNode.primitive.makeDrawingPrimitives(with: resolvedColor)
            } else {
                primitives = node.makeDrawingPrimitives()
            }
            
            if !primitives.isEmpty {
                var transform = node.worldTransform
                let worldPrimitives = primitives.map { $0.applying(transform: &transform) }
                
                let layerId = (node as? Layerable)?.layerId
                primitivesByLayer[layerId, default: []].append(contentsOf: worldPrimitives)
            }
        }
        return primitivesByLayer
    }
    
    /// Collects and transforms all "halo" drawing primitives for highlighted nodes, grouped by layer. 
    private func gatherHaloPrimitives(from context: RenderContext, allNodes: [BaseNode]) -> [UUID?: [DrawingPrimitive]] {
        var primitivesByLayer: [UUID?: [DrawingPrimitive]] = [:]
        let highlightedNodes = context.highlightedNodeIDs.compactMap { id in
            allNodes.first { $0.id == id }
        }
        
        var handledNodeIDs = Set<UUID>()

        // --- PHASE 1: Generate Unified Halos from Parent Containers (THE FIX) ---
        
        // Find all unique parent nodes that contain one or more selected children.
        let parentNodes = Set(highlightedNodes.compactMap { $0.parent })
        
        for parent in parentNodes {
            // Ask the parent to generate a single, pre-stroked halo path for ALL of its selected children.
            // Both SchematicGraphNode and TraceGraphNode override this method.
            if let unifiedHaloPath = parent.makeHaloPath(context: context) {
                
                // The unified path is an outline that should be FILLED to create the halo effect.
                let haloColor = NSColor.systemBlue.withAlphaComponent(0.4).cgColor
                let haloPrimitive = DrawingPrimitive.fill(path: unifiedHaloPath, color: haloColor)
                
                // Add the primitive to the list. Unlayered halos go in the 'nil' key group.
                primitivesByLayer[nil, default: []].append(haloPrimitive)
                
                // Mark all selected children of this parent as "handled" to prevent them
                // from drawing their own individual halos in Phase 2.
                for child in parent.children where context.highlightedNodeIDs.contains(child.id) {
                    handledNodeIDs.insert(child.id)
                }
            }
        }

        // --- PHASE 2: Generate Individual Halos for All Other Nodes ---
        // This phase handles selected nodes that did NOT have a parent provide a unified halo.
        // (e.g., a selected SymbolNode or FootprintNode)

        for node in highlightedNodes {
            // If this node was handled by its parent in Phase 1, skip it.
            guard !handledNodeIDs.contains(node.id) else { continue }
            
            // This is the original logic for nodes that draw their own halos.
            // It's important to keep this for things that aren't part of a graph.
            if let haloPath = node.makeHaloPath() {
                let haloColor = NSColor.systemBlue.withAlphaComponent(0.4).cgColor
                
                // This assumes the node returns its centerline, which we then STROKE.
                let haloPrimitive = DrawingPrimitive.stroke(
                    path: haloPath,
                    color: haloColor,
                    lineWidth: 5.0,
                    lineCap: .round,
                    lineJoin: .round
                )
                    
                var transform = node.worldTransform
                let worldPrimitive = haloPrimitive.applying(transform: &transform)
                
                let layerId = (node as? Layerable)?.layerId
                primitivesByLayer[layerId, default: []].append(worldPrimitive)
            }
        }
        
        return primitivesByLayer
    }
    
    /// Renders a list of already-transformed primitives onto a target CALayer.
    private func render(primitives: [DrawingPrimitive], onto parentLayer: CALayer) {
        for primitive in primitives {
            let shapeLayer = createShapeLayer(for: primitive)
            parentLayer.addSublayer(shapeLayer)
        }
    }

    // MARK: - Helpers

    /// Determines the final color for any node.
    private func resolveColor(for node: BaseNode, in context: RenderContext) -> CGColor {
        if let primitiveNode = node as? PrimitiveNode {
            if let overrideColor = primitiveNode.primitive.color { return overrideColor.cgColor }
            if let layerId = primitiveNode.layerId, let layer = context.layers.first(where: { $0.id == layerId }) {
                return layer.color
            }
        }
        // Fallback for non-primitive nodes or unlayered primitives.
        return NSColor.systemBlue.cgColor
    }
    
    private func reconcileLayers(context: RenderContext, hostLayer: CALayer) {
        let currentLayerIds = Set(backingLayers.keys)
        let modelLayerIds = Set(context.layers.map { $0.id })
        
        for id in currentLayerIds.subtracting(modelLayerIds) {
            backingLayers[id]?.removeFromSuperlayer()
            backingLayers.removeValue(forKey: id)
        }
        
        for layerModel in context.layers where !currentLayerIds.contains(layerModel.id) {
            let newLayer = CALayer(); newLayer.zPosition = CGFloat(layerModel.zIndex); hostLayer.addSublayer(newLayer); backingLayers[layerModel.id] = newLayer
        }
        
        for layerModel in context.layers {
            let backingLayer = backingLayers[layerModel.id]; backingLayer?.isHidden = !layerModel.isVisible; backingLayer?.zPosition = CGFloat(layerModel.zIndex)
        }
    }
    
    private func getOrCreateDefaultLayer(on hostLayer: CALayer) -> CALayer {
        if let defaultLayer = self.defaultLayer { return defaultLayer }
        let newLayer = CALayer(); newLayer.zPosition = -1; hostLayer.addSublayer(newLayer); self.defaultLayer = newLayer; return newLayer
    }

    private func createShapeLayer(for primitive: DrawingPrimitive) -> CAShapeLayer {
        let shapeLayer = CAShapeLayer();
        switch primitive {
        case let .fill(path, color, rule):
            shapeLayer.path = path; shapeLayer.fillColor = color; shapeLayer.fillRule = rule; shapeLayer.strokeColor = nil; shapeLayer.lineWidth = 0
        case let .stroke(path, color, lineWidth, lineCap, lineJoin, miterLimit, lineDash):
            shapeLayer.path = path; shapeLayer.strokeColor = color; shapeLayer.lineWidth = lineWidth; shapeLayer.lineCap = lineCap; shapeLayer.lineJoin = lineJoin; shapeLayer.miterLimit = miterLimit; shapeLayer.lineDashPattern = lineDash; shapeLayer.fillColor = nil
        }
        return shapeLayer
    }

    private func flatten(node: BaseNode) -> [BaseNode] {
        return [node] + node.children.flatMap { flatten(node: $0) }
    }
}
