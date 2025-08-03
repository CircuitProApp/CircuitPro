import AppKit

class PreviewRenderLayer: RenderLayer {
    var layerKey: String = "preview"
    
    func makeLayers(context: RenderContext) -> [CALayer] {
        // 1. Ensure there is an active tool and a mouse location.
        guard var tool = context.selectedTool,
              tool.id != "cursor",
              let mouse = context.mouseLocation
        else {
            return []
        }
        
        // 2. The legacy context is gone! We now pass the main RenderContext directly.
        // The tool's `preview` method signature now matches the context we have.
        let drawingParams = tool.preview(mouse: mouse, context: context)
        
        // 3. Create the CALayers from the drawing parameters.
        // The preview draws in model space, so its line widths should not be scaled down by magnification.
        return drawingParams.map { createLayer(from: $0) }
    }
    
    private func createLayer(from parameters: DrawingParameters) -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.path = parameters.path
        layer.fillColor = parameters.fillColor
        layer.strokeColor = parameters.strokeColor
        layer.lineWidth = parameters.lineWidth // Not scaled, so it previews correctly
        layer.lineDashPattern = parameters.lineDashPattern
        layer.lineCap = parameters.lineCap
        layer.lineJoin = parameters.lineJoin
        layer.fillRule = parameters.fillRule
        return layer
    }
}
