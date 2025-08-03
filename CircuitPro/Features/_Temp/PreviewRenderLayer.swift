//
//  PreviewRenderLayer.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/3/25.
//


import AppKit

class PreviewRenderLayer: RenderLayer {
    var layerKey: String = "preview"
    

    func makeLayers(context: RenderContext) -> [CALayer] {
        guard var tool = context.selectedTool,
              tool.id != "cursor",
              let mouse = context.mouseLocation
        else {
            return []
        }
        
        // Create the legacy context for the tool
        let legacyContext = CanvasToolContext(
            magnification: context.magnification,
            schematicGraph: context.schematicGraph
        )

        let snappedMouse = mouse // Snapping is handled by the coordinator
        let drawingParams = tool.preview(mouse: snappedMouse, context: legacyContext)
        
        // The preview draws in model space, so its line widths should not be scaled down.
        return drawingParams.map { createLayer(from: $0) }
    }
    
    private func createLayer(from parameters: DrawingParameters) -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.path = parameters.path
        layer.fillColor = parameters.fillColor
        layer.strokeColor = parameters.strokeColor
        layer.lineWidth = parameters.lineWidth // Not scaled
        layer.lineDashPattern = parameters.lineDashPattern
        layer.lineCap = parameters.lineCap
        layer.lineJoin = parameters.lineJoin
        layer.fillRule = parameters.fillRule
        return layer
    }
}
