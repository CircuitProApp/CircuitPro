//
//  HandlesRenderLayer.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/3/25.
//


import AppKit

class HandlesRenderLayer: RenderLayer {
    var layerKey: String = "handles"

    func makeLayers(context: RenderContext) -> [CALayer] {
        // Condition 1: Ensure only one element is selected.
        guard context.selectedIDs.count == 1,
              // Condition 2: Find that selected element and ensure it's editable.
              let element = context.elements.first(where: { context.selectedIDs.contains($0.id) && $0.isPrimitiveEditable })
        else {
            return []
        }
        
        // Get the handles from the element.
        let handles = element.handles()
        
        // Condition 3: Ensure the element actually has handles to draw.
        guard !handles.isEmpty else {
            return []
        }
        
        // If all conditions pass, proceed to create the layer.
        let path = CGMutablePath()
        let handleScreenSize: CGFloat = 10.0
        let sizeInModelCoordinates = handleScreenSize / max(context.magnification, .ulpOfOne)
        let half = sizeInModelCoordinates / 2.0

        for handle in handles {
            let handleRect = CGRect(
                x: handle.position.x - half,
                y: handle.position.y - half,
                width: sizeInModelCoordinates,
                height: sizeInModelCoordinates
            )
            path.addEllipse(in: handleRect)
        }

        // The line width must also be scaled to appear constant on screen.
        let lineWidth = 1.0 / max(context.magnification, .ulpOfOne)
        
        let params = DrawingParameters(
            path: path,
            lineWidth: lineWidth,
            fillColor: NSColor.white.cgColor,
            strokeColor: NSColor.systemBlue.cgColor
        )
        
        return [createLayer(from: params)]
    }
    
    private func createLayer(from parameters: DrawingParameters) -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.path = parameters.path
        layer.fillColor = parameters.fillColor
        layer.strokeColor = parameters.strokeColor
        layer.lineWidth = parameters.lineWidth
        return layer
    }
}
