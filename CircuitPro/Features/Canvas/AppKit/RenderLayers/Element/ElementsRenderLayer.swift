//
//  ElementsRenderLayer.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/3/25.
//


import AppKit

class ElementsRenderLayer: RenderLayer {
    var layerKey: String = "elements"

    func makeLayers(context: RenderContext) -> [CALayer] {
        var bodyLayers: [CALayer] = []
        var haloLayers: [CALayer] = []
        
        let allSelectedIDs = context.selectedIDs.union(context.marqueeSelectedIDs)

        for element in context.elements {
            // Create body layers
            for params in element.drawable.makeBodyParameters() {
                bodyLayers.append(createLayer(from: params))
            }
            
            // Create halo layers (passing the full selection context)
            if let haloParams = element.drawable.makeHaloParameters(selectedIDs: allSelectedIDs) {
                haloLayers.append(createLayer(from: haloParams))
            }
        }
        
        // Return halos first so they are drawn behind the bodies.
        return haloLayers + bodyLayers
    }

    private func createLayer(from parameters: DrawingParameters) -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.path = parameters.path
        layer.fillColor = parameters.fillColor
        layer.strokeColor = parameters.strokeColor
        layer.lineWidth = parameters.lineWidth
        layer.lineCap = parameters.lineCap
        layer.lineJoin = parameters.lineJoin
        layer.lineDashPattern = parameters.lineDashPattern
        layer.fillRule = parameters.fillRule
        return layer
    }
    
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
}