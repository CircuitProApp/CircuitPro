import AppKit

struct CKRenderNode {
    var geometry: CKGeometry
    var style: CKStyleState
    var interaction: CKInteractionState?
    var children: [CKRenderNode]
    var renderChildren: Bool
    var excludesFromHitPath: Bool
    var mergeChildPaths: Bool
    var canvasDragHandler: CanvasGlobalDragHandler?
    var transformState: CKTransformState

    init(
        geometry: CKGeometry,
        style: CKStyleState = CKStyleState(),
        interaction: CKInteractionState? = nil,
        children: [CKRenderNode] = [],
        renderChildren: Bool = true,
        excludesFromHitPath: Bool = false,
        mergeChildPaths: Bool = false,
        canvasDragHandler: CanvasGlobalDragHandler? = nil,
        transformState: CKTransformState = CKTransformState()
    ) {
        self.geometry = geometry
        self.style = style
        self.interaction = interaction
        self.children = children
        self.renderChildren = renderChildren
        self.excludesFromHitPath = excludesFromHitPath
        self.mergeChildPaths = mergeChildPaths
        self.canvasDragHandler = canvasDragHandler
        self.transformState = transformState
    }
}

enum CKGeometry {
    case path((RenderContext) -> CGPath)
    case group
}

struct CKTransformState {
    var position: CGPoint = .zero
    var rotation: CGFloat = 0

    func affineTransform() -> CGAffineTransform {
        var transform = CGAffineTransform.identity
        if position != .zero {
            transform = transform.translatedBy(x: position.x, y: position.y)
        }
        if rotation != 0 {
            transform = transform.rotated(by: rotation)
        }
        return transform
    }
}

struct CKStyleState {
    var fill: CKFillStyle?
    var stroke: CKStrokeStyle?
    var halos: [CKHalo] = []
    var clipPath: CGPath?
    var opacity: CGFloat = 1.0
    var colorOverride: CGColor?
}

struct CKHalo {
    var color: CGColor
    var width: CGFloat
}

struct CKFillStyle {
    var color: CGColor
    var rule: CAShapeLayerFillRule
}

struct CKStrokeStyle {
    var color: CGColor
    var width: CGFloat
    var lineCap: CAShapeLayerLineCap
    var lineJoin: CAShapeLayerLineJoin
    var miterLimit: CGFloat
    var lineDash: [NSNumber]?
}

struct CKInteractionState {
    var id: UUID
    var hoverable: Bool
    var selectable: Bool
    var draggable: Bool
    var contentShape: CGPath?
    var hitTestPriority: Int
    var onDragPhase: ((CanvasDragPhase, CanvasDragSession) -> Void)?
    var onDragDelta: ((CanvasDragDelta, CanvasDragSession) -> Void)?
    var onHover: ((Bool) -> Void)?
    var onTap: (() -> Void)?
    var onDrag: ((CanvasDragPhase, CanvasDragSession) -> Void)?
}

struct CKNodeEvaluation {
    let primitives: [DrawingPrimitive]
}

enum CKNodeEvaluator {
    static func render(
        _ node: CKRenderNode,
        context: RenderContext,
        environment: CanvasEnvironmentValues
    ) -> [DrawingPrimitive] {
        evaluate(
            node,
            context: context,
            environment: environment,
            transform: .identity,
            opacity: 1.0,
            colorOverride: nil,
            depth: context.hitTestDepth
        )
    }

    private static func evaluate(
        _ node: CKRenderNode,
        context: RenderContext,
        environment: CanvasEnvironmentValues,
        transform: CGAffineTransform,
        opacity: CGFloat,
        colorOverride: CGColor?,
        depth: Int
    ) -> [DrawingPrimitive] {
        let combinedTransform = node.transformState.affineTransform().concatenating(transform)
        let combinedOpacity = opacity * node.style.opacity
        let combinedOverride = node.style.colorOverride ?? colorOverride
        if let handler = node.canvasDragHandler {
            context.canvasDragHandlers.add(handler)
        }

        let childPrimitives = node.renderChildren
            ? node.children.flatMap {
                evaluate(
                    $0,
                    context: context,
                    environment: environment,
                    transform: combinedTransform,
                    opacity: combinedOpacity,
                    colorOverride: combinedOverride,
                    depth: depth + 1
                )
            }
            : []

        let basePaths = collectPaths(node, context: context, transform: combinedTransform)
        let stylePrimitives = buildStylePrimitives(
            for: basePaths,
            style: node.style,
            transform: combinedTransform,
            opacity: combinedOpacity,
            colorOverride: combinedOverride
        )

        registerInteraction(
            node,
            context: context,
            environment: environment,
            basePaths: basePaths,
            transform: combinedTransform,
            depth: depth
        )

        var output: [DrawingPrimitive] = []
        output.append(contentsOf: stylePrimitives.halos)
        output.append(contentsOf: stylePrimitives.fills)
        output.append(contentsOf: childPrimitives)
        output.append(contentsOf: stylePrimitives.strokes)
        return output
    }

    private static func collectPaths(
        _ node: CKRenderNode,
        context: RenderContext,
        transform: CGAffineTransform
    ) -> [CGPath] {
        switch node.geometry {
        case .path(let builder):
            let base = builder(context)
            guard !base.isEmpty else { return [] }
            var t = transform
            return [base.copy(using: &t) ?? base]
        case .group:
            let paths = node.children.flatMap { child in
                collectPaths(
                    child,
                    context: context,
                    transform: child.transformState.affineTransform().concatenating(transform)
                )
            }
            if node.mergeChildPaths, !paths.isEmpty {
                let merged = CGMutablePath()
                paths.forEach { merged.addPath($0) }
                return [merged]
            }
            return paths
        }
    }

    private struct StylePrimitives {
        var fills: [DrawingPrimitive] = []
        var strokes: [DrawingPrimitive] = []
        var halos: [DrawingPrimitive] = []
    }

    private static func buildStylePrimitives(
        for paths: [CGPath],
        style: CKStyleState,
        transform: CGAffineTransform,
        opacity: CGFloat,
        colorOverride: CGColor?
    ) -> StylePrimitives {
        guard !paths.isEmpty else { return StylePrimitives() }
        let clipPath = style.clipPath.flatMap { path -> CGPath? in
            var t = transform
            return path.copy(using: &t) ?? path
        }

        var result = StylePrimitives()
        let effectiveOpacity = opacity.clamped(to: 0...1)
        let override = colorOverride

        if !style.halos.isEmpty {
            for halo in style.halos where halo.width > 0 {
                let color = halo.color.applyingOpacity(effectiveOpacity)
                for path in paths {
                    result.halos.append(
                        .stroke(
                            path: path,
                            color: color,
                            lineWidth: halo.width,
                            lineCap: .round,
                            lineJoin: .round,
                            miterLimit: 10,
                            lineDash: nil,
                            clipPath: clipPath
                        )
                    )
                }
            }
        }

        if let fill = style.fill {
            let baseColor = shouldOverride(color: fill.color, override: override) ? (override ?? fill.color) : fill.color
            let color = baseColor.applyingOpacity(effectiveOpacity)
            for path in paths {
                result.fills.append(
                    .fill(path: path, color: color, rule: fill.rule, clipPath: clipPath)
                )
            }
        }

        if let stroke = style.stroke {
            let baseColor = shouldOverride(color: stroke.color, override: override) ? (override ?? stroke.color) : stroke.color
            let color = baseColor.applyingOpacity(effectiveOpacity)
            for path in paths {
                result.strokes.append(
                    .stroke(
                        path: path,
                        color: color,
                        lineWidth: stroke.width,
                        lineCap: stroke.lineCap,
                        lineJoin: stroke.lineJoin,
                        miterLimit: stroke.miterLimit,
                        lineDash: stroke.lineDash,
                        clipPath: clipPath
                    )
                )
            }
        }

        return result
    }

    private static func shouldOverride(color: CGColor, override: CGColor?) -> Bool {
        guard override != nil else { return false }
        return color.alpha > 0.001
    }

    private static func registerInteraction(
        _ node: CKRenderNode,
        context: RenderContext,
        environment: CanvasEnvironmentValues,
        basePaths: [CGPath],
        transform: CGAffineTransform,
        depth: Int
    ) {
        guard let interaction = node.interaction, !node.excludesFromHitPath else { return }
        if basePaths.isEmpty && interaction.contentShape == nil {
            return
        }

        let hitPath: CGPath
        if let shape = interaction.contentShape {
            var t = transform
            hitPath = shape.copy(using: &t) ?? shape
        } else {
            let merged = CGMutablePath()
            for path in basePaths {
                merged.addPath(path)
            }
            hitPath = expandedHitPath(
                for: merged,
                stroke: node.style.stroke,
                halos: node.style.halos,
                magnification: context.magnification
            )
        }

        if hitPath.isEmpty {
            return
        }

        let hoverHandler = environment.onHoverItem
        let tapHandler = environment.onTapItem
        let dragHandler = environment.onDragItem

        let onHover: ((Bool) -> Void)? = interaction.onHover ?? (interaction.hoverable ? { isInside in
            hoverHandler?(interaction.id, isInside)
        } : nil)

        let onTap: (() -> Void)? = interaction.onTap ?? (interaction.selectable ? {
            tapHandler?(interaction.id)
        } : nil)

        let onDrag: ((CanvasDragPhase, CanvasDragSession) -> Void)? = interaction.onDrag ?? ((interaction.draggable || interaction.onDragPhase != nil || interaction.onDragDelta != nil) ? { phase, session in
            if interaction.draggable {
                dragHandler?(interaction.id, phase)
            }
            interaction.onDragPhase?(phase, session)
            if case let .changed(delta) = phase {
                interaction.onDragDelta?(delta, session)
            }
        } : nil)

        if onHover != nil || onTap != nil || onDrag != nil {
            context.hitTargets.add(
                CanvasHitTarget(
                    id: interaction.id,
                    path: hitPath,
                    priority: interaction.hitTestPriority,
                    depth: depth,
                    onHover: onHover,
                    onTap: onTap,
                    onDrag: onDrag
                )
            )
        }
    }

    private static func expandedHitPath(
        for path: CGPath,
        stroke: CKStrokeStyle?,
        halos: [CKHalo],
        magnification: CGFloat
    ) -> CGPath {
        guard !path.isEmpty else { return CGMutablePath() }
        let strokeWidth = stroke?.width ?? 0
        let haloWidth = halos.map(\.width).max() ?? 0
        let baseWidth = 5.0 / max(magnification, 0.001)
        let width = max(strokeWidth, haloWidth, baseWidth)
        return path.copy(
            strokingWithWidth: width,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 10
        )
    }
}
