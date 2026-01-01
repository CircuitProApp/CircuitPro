// Features/Canvas/RenderLayers/ElementsRenderLayer.swift

import AppKit

/// Renders all graph-backed elements and their selection halos, organizing them into a hierarchy
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

        // --- 4. GATHER ALL PRIMITIVES FIRST ---

        var bodyPrimitivesByLayer: [UUID?: [DrawingPrimitive]] = [:]
        var haloPrimitivesByLayer: [UUID?: [DrawingPrimitive]] = [:]

        let graph = context.graph
        let graphHalos = gatherHaloPrimitives(from: graph, context: context)
        for (layerId, primitives) in graphHalos {
            haloPrimitivesByLayer[layerId, default: []].append(contentsOf: primitives)
        }
        for provider in context.environment.graphHaloProviders {
            let provided = provider.haloPrimitives(
                from: graph,
                context: context,
                highlightedIDs: context.highlightedElementIDs
            )
            for (layerId, primitives) in provided {
                haloPrimitivesByLayer[layerId, default: []].append(contentsOf: primitives)
            }
        }

        let graphAdapter = GraphRenderAdapter()
        let graphPrimitivesByLayer = graphAdapter.primitivesByLayer(from: graph, context: context)
        for (layerId, primitives) in graphPrimitivesByLayer {
            bodyPrimitivesByLayer[layerId, default: []].append(contentsOf: primitives)
        }
        for provider in context.environment.graphRenderProviders {
            let provided = provider.primitivesByLayer(from: graph, context: context)
            for (layerId, primitives) in provided {
                bodyPrimitivesByLayer[layerId, default: []].append(contentsOf: primitives)
            }
        }

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

    private func gatherHaloPrimitives(from graph: CanvasGraph, context: RenderContext) -> [UUID?: [DrawingPrimitive]] {
        var primitivesByLayer: [UUID?: [DrawingPrimitive]] = [:]
        let haloIDs = context.highlightedElementIDs

        for (id, item) in graph.allComponentsConforming((any HaloProviding).self) {
            guard haloIDs.contains(id) else { continue }
            guard let haloPath = item.haloPath() else { continue }

            let haloColor = NSColor.systemBlue.withAlphaComponent(0.4).cgColor
            let haloPrimitive = DrawingPrimitive.stroke(
                path: haloPath,
                color: haloColor,
                lineWidth: 5.0,
                lineCap: .round,
                lineJoin: .round
            )

            let layerTargets: [UUID?]
            if let multiLayerable = item as? MultiLayerable, !multiLayerable.layerIds.isEmpty {
                layerTargets = multiLayerable.layerIds.map { Optional($0) }
            } else if let layerable = item as? Layerable {
                layerTargets = [layerable.layerId]
            } else {
                layerTargets = [nil]
            }

            for layerId in layerTargets {
                primitivesByLayer[layerId, default: []].append(haloPrimitive)
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

}
