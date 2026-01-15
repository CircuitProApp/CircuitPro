import AppKit

protocol CKRenderer {
    func install(on hostLayer: CALayer)
    func render(views: [any CKView], context: RenderContext, environment: CanvasEnvironmentValues)
}

final class DefaultCKRenderer: CKRenderer {
    private let rootLayer = CALayer()
    private var shapeLayerPool: [CAShapeLayer] = []
    private let stateStore = CKStateStore()

    func install(on hostLayer: CALayer) {
        rootLayer.contentsScale = hostLayer.contentsScale
        hostLayer.addSublayer(rootLayer)
    }

    func render(views: [any CKView], context: RenderContext, environment: CanvasEnvironmentValues) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        rootLayer.frame = context.canvasBounds

        CKContextStorage.current = context
        CKContextStorage.last = context
        CKContextStorage.environment = environment
        CKContextStorage.lastEnvironment = environment
        CKContextStorage.stateStore = stateStore
        CKContextStorage.resetViewScope()
        let batches = buildBatches(from: views, context: context, environment: environment)
        CKContextStorage.current = nil
        CKContextStorage.environment = nil

        if batches.isEmpty {
            hideAllLayers()
            CATransaction.commit()
            return
        }

        var currentLayerIndex = 0
        for batch in batches {
            let shapeLayer = layer(at: currentLayerIndex)
            configure(layer: shapeLayer, for: batch, zIndex: currentLayerIndex)
            currentLayerIndex += 1
        }

        if currentLayerIndex < shapeLayerPool.count {
            for i in currentLayerIndex..<shapeLayerPool.count {
                shapeLayerPool[i].isHidden = true
            }
        }

        CATransaction.commit()
    }

    private func buildBatches(
        from views: [any CKView],
        context: RenderContext,
        environment: CanvasEnvironmentValues
    ) -> [PrimitiveBatch] {
        var batches: [PrimitiveBatch] = []

        for (index, view) in views.enumerated() {
            guard let node = context.node(view, index: index) else { continue }
            let primitives = CKNodeEvaluator.render(node, context: context, environment: environment)
            let forceBatchBreak = view is ToolPreviewView
            var isFirstPrimitive = true
            for primitive in primitives {
                let key = BatchKey(primitive: primitive)
                if let last = batches.last, last.key == key, !(forceBatchBreak && isFirstPrimitive) {
                    batches[batches.count - 1].append(primitive)
                } else {
                    batches.append(PrimitiveBatch(key: key, primitive: primitive))
                }
                isFirstPrimitive = false
            }
        }

        return batches
    }

    private func hideAllLayers() {
        for layer in shapeLayerPool {
            layer.isHidden = true
        }
    }

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

    private func configure(layer: CAShapeLayer, for batch: PrimitiveBatch, zIndex: Int) {
        layer.frame = rootLayer.bounds
        layer.contentsScale = rootLayer.contentsScale
        layer.zPosition = CGFloat(zIndex)

        switch batch.key.kind {
        case .fill(let color, let rule, let clipPath):
            layer.path = batch.path
            layer.fillColor = color
            layer.fillRule = rule
            layer.strokeColor = nil
            layer.lineWidth = 0
            layer.lineDashPattern = nil
            applyClip(clipPath, to: layer)

        case .stroke(let color, let lineWidth, let lineCap, let lineJoin, let miterLimit, let lineDash, let clipPath):
            layer.path = batch.path
            layer.fillColor = nil
            layer.strokeColor = color
            layer.lineWidth = lineWidth
            layer.lineCap = lineCap
            layer.lineJoin = lineJoin
            layer.miterLimit = miterLimit
            layer.lineDashPattern = lineDash
            applyClip(clipPath, to: layer)
        }
    }

    private func applyClip(_ clipPath: CGPath?, to layer: CAShapeLayer) {
        guard let clipPath else {
            layer.mask = nil
            return
        }
        let maskLayer = (layer.mask as? CAShapeLayer) ?? CAShapeLayer()
        maskLayer.frame = layer.bounds
        maskLayer.contentsScale = layer.contentsScale
        maskLayer.path = clipPath
        layer.mask = maskLayer
    }
}

private struct PrimitiveBatch {
    let key: BatchKey
    private(set) var path: CGMutablePath

    init(key: BatchKey, primitive: DrawingPrimitive) {
        self.key = key
        self.path = CGMutablePath()
        append(primitive)
    }

    mutating func append(_ primitive: DrawingPrimitive) {
        switch primitive {
        case let .fill(path, _, _, _):
            path.isEmpty ? () : self.path.addPath(path)
        case let .stroke(path, _, _, _, _, _, _, _):
            path.isEmpty ? () : self.path.addPath(path)
        }
    }
}

private struct BatchKey: Equatable {
    enum Kind: Equatable {
        case fill(color: CGColor, rule: CAShapeLayerFillRule, clipPath: CGPath?)
        case stroke(
            color: CGColor,
            lineWidth: CGFloat,
            lineCap: CAShapeLayerLineCap,
            lineJoin: CAShapeLayerLineJoin,
            miterLimit: CGFloat,
            lineDash: [NSNumber]?,
            clipPath: CGPath?
        )
    }

    let kind: Kind

    init(primitive: DrawingPrimitive) {
        switch primitive {
        case let .fill(_, color, rule, clipPath):
            self.kind = .fill(color: color, rule: rule, clipPath: clipPath)
        case let .stroke(_, color, lineWidth, lineCap, lineJoin, miterLimit, lineDash, clipPath):
            self.kind = .stroke(
                color: color,
                lineWidth: lineWidth,
                lineCap: lineCap,
                lineJoin: lineJoin,
                miterLimit: miterLimit,
                lineDash: lineDash,
                clipPath: clipPath
            )
        }
    }
}
