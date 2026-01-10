import AppKit

class PreviewRenderLayer: RenderLayer {

    // A persistent container layer for all preview shapes.
    private let rootLayer = CALayer()

    // The pool can be simplified back to only CAShapeLayers, since text is
    // now also rendered as a vector path.
    private var shapeLayerPool: [CAShapeLayer] = []

    func install(on hostLayer: CALayer) {
        rootLayer.contentsScale = hostLayer.contentsScale
        hostLayer.addSublayer(rootLayer)
    }

    func update(using context: RenderContext) {
        guard let tool = context.selectedTool,
              let mouseLocation = context.processedMouseLocation
        else {
            hideAllLayers()
            return
        }

        // Get the drawing primitives from the tool. These are already in world coordinates.
        let drawingPrimitives = tool.preview(mouse: mouseLocation, context: context)

        guard !drawingPrimitives.isEmpty else {
            hideAllLayers()
            return
        }

        // Use a loop to dispatch each primitive to the correct configuration method.
        // The switch now only handles fill and stroke cases.
        var currentLayerIndex = 0
        for primitive in drawingPrimitives {
            let shapeLayer = layer(at: currentLayerIndex)
            switch primitive {
            case let .fill(path, color, rule, clipPath):
                configure(layer: shapeLayer, forFill: path, color: color, rule: rule, clipPath: clipPath)

            case let .stroke(path, color, lineWidth, lineCap, lineJoin, miterLimit, lineDash, clipPath):
                configure(layer: shapeLayer, forStroke: path, color: color, lineWidth: lineWidth, lineCap: lineCap, lineJoin: lineJoin, miterLimit: miterLimit, lineDash: lineDash, clipPath: clipPath)

            // The .text case is correctly removed.
            }
            currentLayerIndex += 1
        }

        // Hide any remaining, unused layers in the pool.
        if currentLayerIndex < shapeLayerPool.count {
            for i in currentLayerIndex..<shapeLayerPool.count {
                shapeLayerPool[i].isHidden = true
            }
        }
    }

    // MARK: - Layer Management

    private func hideAllLayers() {
        for layer in shapeLayerPool {
            layer.isHidden = true
        }
    }

    /// The layer pooling logic is simplified back to only handle CAShapeLayers.
    private func layer(at index: Int) -> CAShapeLayer {
        if index < shapeLayerPool.count {
            let layer = shapeLayerPool[index]
            layer.isHidden = false
            return layer
        }

        let newLayer = CAShapeLayer()
        shapeLayerPool.append(newLayer)
        rootLayer.addSublayer(newLayer)
        return newLayer
    }

    // MARK: - Layer Configuration

    // The text-related configuration and helper methods have been removed.

    private func configure(layer: CAShapeLayer, forFill path: CGPath, color: CGColor, rule: CAShapeLayerFillRule, clipPath: CGPath?) {
        layer.path = path
        layer.fillColor = color
        layer.fillRule = rule
        layer.strokeColor = nil
        layer.lineWidth = 0
        applyClip(clipPath, to: layer)
    }

    private func configure(layer: CAShapeLayer, forStroke path: CGPath, color: CGColor, lineWidth: CGFloat, lineCap: CAShapeLayerLineCap, lineJoin: CAShapeLayerLineJoin, miterLimit: CGFloat, lineDash: [NSNumber]?, clipPath: CGPath?) {
        layer.path = path
        layer.fillColor = nil
        layer.strokeColor = color
        layer.lineWidth = lineWidth
        layer.lineCap = lineCap
        layer.lineJoin = lineJoin
        layer.miterLimit = miterLimit
        layer.lineDashPattern = lineDash
        applyClip(clipPath, to: layer)
    }

    private func applyClip(_ clipPath: CGPath?, to layer: CAShapeLayer) {
        guard let clipPath else {
            layer.mask = nil
            return
        }
        let maskLayer = (layer.mask as? CAShapeLayer) ?? CAShapeLayer()
        maskLayer.path = clipPath
        layer.mask = maskLayer
    }
}
