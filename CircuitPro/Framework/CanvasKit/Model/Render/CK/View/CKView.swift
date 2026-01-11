import AppKit

protocol CKView {
    associatedtype Body: CKView
    @CKViewBuilder var body: Body { get }
    func _render(in context: RenderContext) -> [DrawingPrimitive]
    func _paths(in context: RenderContext) -> [CGPath]
}

protocol CKHitTestable {
    func hitTestPath(in context: RenderContext) -> CGPath
}

struct CKInteractionView<Content: CKView>: CKView {
    typealias Body = Never

    let content: Content
    let targetID: UUID
    var isHoverable: Bool
    var isSelectable: Bool
    var isDraggable: Bool
    var contentShape: CGPath?
    var dragPhaseHandler: ((CanvasDragPhase) -> Void)?
    var dragDeltaHandler: ((CanvasDragDelta) -> Void)?

    var body: Never {
        fatalError("CKInteractionView has no body.")
    }

    func _render(in context: RenderContext) -> [DrawingPrimitive] {
        let primitives = content._render(in: context)
        let targetPath = contentShape ?? hitPath(in: context, primitives: primitives)
        if targetPath.isEmpty {
            return primitives
        }

        let hoverHandler = context.environment.onHoverItem
        let tapHandler = context.environment.onTapItem
        let dragHandler = context.environment.onDragItem

        let onHover: ((Bool) -> Void)? = isHoverable ? { isInside in
            hoverHandler?(targetID, isInside)
        } : nil

        let onTap: (() -> Void)? = isSelectable ? {
            tapHandler?(targetID)
        } : nil

        let onDrag: ((CanvasDragPhase) -> Void)? = (isDraggable || dragPhaseHandler != nil || dragDeltaHandler != nil) ? { phase in
            if isDraggable {
                dragHandler?(targetID, phase)
            }
            dragPhaseHandler?(phase)
            if case let .changed(delta) = phase {
                dragDeltaHandler?(delta)
            }
        } : nil

        if onHover != nil || onTap != nil || onDrag != nil {
            context.hitTargets.add(
                CanvasHitTarget(
                    id: targetID,
                    path: targetPath,
                    onHover: onHover,
                    onTap: onTap,
                    onDrag: onDrag
                )
            )
        }

        return primitives
    }

    private func hitPath(in context: RenderContext, primitives: [DrawingPrimitive]) -> CGPath {
        if let hitTestable = content as? any CKHitTestable {
            let path = hitTestable.hitTestPath(in: context)
            if !path.isEmpty {
                return path
            }
        }
        if primitives.isEmpty {
            let paths = content._paths(in: context).filter { !$0.isEmpty }
            if !paths.isEmpty {
                let merged = CGMutablePath()
                for path in paths {
                    merged.addPath(path)
                }
                return merged
            }
        }
        let union = primitivesBoundingBox(primitives)
        guard !union.isNull, !union.isEmpty else { return CGMutablePath() }
        return CGPath(rect: union, transform: nil)
    }

    private func primitivesBoundingBox(_ primitives: [DrawingPrimitive]) -> CGRect {
        var rect = CGRect.null
        for primitive in primitives {
            let box = primitive.boundingBox
            if rect.isNull {
                rect = box
            } else {
                rect = rect.union(box)
            }
        }
        return rect
    }
}

extension Never: CKView {
    var body: Never {
        fatalError("Never has no body.")
    }

    func _render(in context: RenderContext) -> [DrawingPrimitive] {
        []
    }
}

extension CKView {
    func _render(in context: RenderContext) -> [DrawingPrimitive] {
        body._render(in: context)
    }

    func _paths(in context: RenderContext) -> [CGPath] {
        _render(in: context).compactMap { $0.path }
    }
}

struct CKTransformView<Content: CKView>: CKView {
    typealias Body = Never

    let content: Content
    var position: CGPoint?
    var rotation: CGFloat

    var body: Never {
        fatalError("CKTransformView has no body.")
    }

    func _render(in context: RenderContext) -> [DrawingPrimitive] {
        applyTransforms(to: content._render(in: context))
    }

    func _paths(in context: RenderContext) -> [CGPath] {
        applyTransforms(to: content._paths(in: context))
    }

    private func applyTransforms(to primitives: [DrawingPrimitive]) -> [DrawingPrimitive] {
        var transformed = primitives
        if let position {
            var translation = CGAffineTransform(translationX: position.x, y: position.y)
            transformed = transformed.map { $0.applying(transform: &translation) }
        }
        if rotation != 0 {
            let pivot = position ?? .zero
            var rotationTransform = CGAffineTransform(
                translationX: pivot.x,
                y: pivot.y
            )
            .rotated(by: rotation)
            .translatedBy(x: -pivot.x, y: -pivot.y)
            transformed = transformed.map { $0.applying(transform: &rotationTransform) }
        }
        return transformed
    }

    private func applyTransforms(to paths: [CGPath]) -> [CGPath] {
        var transformed = paths
        if let position {
            var translation = CGAffineTransform(translationX: position.x, y: position.y)
            transformed = transformed.map { $0.copy(using: &translation) ?? $0 }
        }
        if rotation != 0 {
            let pivot = position ?? .zero
            var rotationTransform = CGAffineTransform(
                translationX: pivot.x,
                y: pivot.y
            )
            .rotated(by: rotation)
            .translatedBy(x: -pivot.x, y: -pivot.y)
            transformed = transformed.map { $0.copy(using: &rotationTransform) ?? $0 }
        }
        return transformed
    }
}

struct CKStrokeView<Content: CKView>: CKView {
    typealias Body = Never

    let content: Content
    var color: CGColor
    var width: CGFloat
    var lineCap: CAShapeLayerLineCap = .round
    var lineJoin: CAShapeLayerLineJoin = .miter
    var miterLimit: CGFloat = 10
    var lineDash: [NSNumber]?
    var clipPath: CGPath?

    var body: Never {
        fatalError("CKStrokeView has no body.")
    }

    func _render(in context: RenderContext) -> [DrawingPrimitive] {
        let strokes = content._paths(in: context)
            .filter { !$0.isEmpty }
            .map {
                DrawingPrimitive.stroke(
                    path: $0,
                    color: color,
                    lineWidth: width,
                    lineCap: lineCap,
                    lineJoin: lineJoin,
                    miterLimit: miterLimit,
                    lineDash: lineDash,
                    clipPath: clipPath
                )
            }
        return strokes
    }
}

struct CKFillView<Content: CKView>: CKView {
    typealias Body = Never

    let content: Content
    var color: CGColor
    var rule: CAShapeLayerFillRule = .nonZero
    var clipPath: CGPath?

    var body: Never {
        fatalError("CKFillView has no body.")
    }

    func _render(in context: RenderContext) -> [DrawingPrimitive] {
        let fills = content._paths(in: context)
            .filter { !$0.isEmpty }
            .map { DrawingPrimitive.fill(path: $0, color: color, rule: rule, clipPath: clipPath) }
        return fills
    }
}

struct CKHaloView<Content: CKView>: CKView {
    typealias Body = Never

    let content: Content
    var color: CGColor
    var width: CGFloat

    var body: Never {
        fatalError("CKHaloView has no body.")
    }

    func _render(in context: RenderContext) -> [DrawingPrimitive] {
        let base = content._render(in: context)
        let halos = content._paths(in: context)
            .filter { !$0.isEmpty }
            .map {
                DrawingPrimitive.stroke(
                    path: $0,
                    color: color,
                    lineWidth: width,
                    lineCap: .round,
                    lineJoin: .round,
                    miterLimit: 10,
                    lineDash: nil,
                    clipPath: nil
                )
            }
        return halos + base
    }
}

struct CKClipView<Content: CKView>: CKView {
    typealias Body = Never

    let content: Content
    var clipPath: CGPath

    var body: Never {
        fatalError("CKClipView has no body.")
    }

    func _render(in context: RenderContext) -> [DrawingPrimitive] {
        content._render(in: context).map { $0.withClip(clipPath) }
    }
}

struct CKHitTargetView<Content: CKView>: CKView {
    typealias Body = Never

    let content: Content
    let contentShape: CGPath?
    let onHover: ((Bool) -> Void)?
    let onTap: (() -> Void)?
    let onDrag: ((CanvasDragPhase) -> Void)?
    let targetID: UUID

    var body: Never {
        fatalError("CKHitTargetView has no body.")
    }

    func _render(in context: RenderContext) -> [DrawingPrimitive] {
        let primitives = content._render(in: context)
        let targetPath = contentShape ?? hitPath(in: context, primitives: primitives)
        if !targetPath.isEmpty {
            context.hitTargets.add(
                CanvasHitTarget(
                    id: targetID,
                    path: targetPath,
                    onHover: onHover,
                    onTap: onTap,
                    onDrag: onDrag
                )
            )
        }
        return primitives
    }

    private func hitPath(in context: RenderContext, primitives: [DrawingPrimitive]) -> CGPath {
        if let hitTestable = content as? any CKHitTestable {
            let path = hitTestable.hitTestPath(in: context)
            if !path.isEmpty {
                return path
            }
        }
        let union = primitivesBoundingBox(primitives)
        guard !union.isNull, !union.isEmpty else { return CGMutablePath() }
        return CGPath(rect: union, transform: nil)
    }

    private func primitivesBoundingBox(_ primitives: [DrawingPrimitive]) -> CGRect {
        var rect = CGRect.null
        for primitive in primitives {
            let box = primitive.boundingBox
            if rect.isNull {
                rect = box
            } else {
                rect = rect.union(box)
            }
        }
        return rect
    }
}

extension CKView {
    func position(_ point: CGPoint) -> CKTransformView<Self> {
        CKTransformView(content: self, position: point, rotation: 0)
    }

    func position(x: CGFloat, y: CGFloat) -> CKTransformView<Self> {
        position(CGPoint(x: x, y: y))
    }

    func rotation(_ angle: CGFloat) -> CKTransformView<Self> {
        CKTransformView(content: self, position: nil, rotation: angle)
    }

    func stroke(_ color: CGColor, width: CGFloat = 1.0) -> CKStrokeView<Self> {
        CKStrokeView(content: self, color: color, width: width)
    }

    func fill(_ color: CGColor) -> CKFillView<Self> {
        CKFillView(content: self, color: color)
    }

    func fill(_ color: CGColor, rule: CAShapeLayerFillRule) -> CKFillView<Self> {
        CKFillView(content: self, color: color, rule: rule)
    }

    func halo(_ color: CGColor, width: CGFloat) -> CKHaloView<Self> {
        CKHaloView(content: self, color: color, width: width)
    }

    func clip(_ path: CGPath) -> CKClipView<Self> {
        CKClipView(content: self, clipPath: path)
    }

    func clip(to rect: CGRect) -> CKClipView<Self> {
        CKClipView(content: self, clipPath: CGPath(rect: rect, transform: nil))
    }

    func hoverable(_ id: UUID) -> CKInteractionView<Self> {
        CKInteractionView(
            content: self,
            targetID: id,
            isHoverable: true,
            isSelectable: false,
            isDraggable: false,
            contentShape: nil,
            dragPhaseHandler: nil,
            dragDeltaHandler: nil
        )
    }

    func selectable(_ id: UUID) -> CKInteractionView<Self> {
        CKInteractionView(
            content: self,
            targetID: id,
            isHoverable: false,
            isSelectable: true,
            isDraggable: false,
            contentShape: nil,
            dragPhaseHandler: nil,
            dragDeltaHandler: nil
        )
    }

    func onDragGesture(_ action: @escaping (CanvasDragPhase) -> Void) -> CKInteractionView<Self> {
        CKInteractionView(
            content: self,
            targetID: UUID(),
            isHoverable: false,
            isSelectable: false,
            isDraggable: false,
            contentShape: nil,
            dragPhaseHandler: action,
            dragDeltaHandler: nil
        )
    }

    func onDragGesture(_ action: @escaping (CanvasDragDelta) -> Void) -> CKInteractionView<Self> {
        CKInteractionView(
            content: self,
            targetID: UUID(),
            isHoverable: false,
            isSelectable: false,
            isDraggable: false,
            contentShape: nil,
            dragPhaseHandler: nil,
            dragDeltaHandler: action
        )
    }

    func contentShape(_ path: CGPath) -> CKHitTargetView<Self> {
        CKHitTargetView(
            content: self,
            contentShape: path,
            onHover: nil,
            onTap: nil,
            onDrag: nil,
            targetID: UUID()
        )
    }

    func contentShape(_ path: CGPath, id: UUID) -> CKHitTargetView<Self> {
        CKHitTargetView(
            content: self,
            contentShape: path,
            onHover: nil,
            onTap: nil,
            onDrag: nil,
            targetID: id
        )
    }

    func onHover(_ action: @escaping (Bool) -> Void) -> CKHitTargetView<Self> {
        CKHitTargetView(
            content: self,
            contentShape: nil,
            onHover: action,
            onTap: nil,
            onDrag: nil,
            targetID: UUID()
        )
    }

    func onHover(id: UUID, _ action: @escaping (Bool) -> Void) -> CKHitTargetView<Self> {
        CKHitTargetView(
            content: self,
            contentShape: nil,
            onHover: action,
            onTap: nil,
            onDrag: nil,
            targetID: id
        )
    }

    func onTap(_ action: @escaping () -> Void) -> CKHitTargetView<Self> {
        CKHitTargetView(
            content: self,
            contentShape: nil,
            onHover: nil,
            onTap: action,
            onDrag: nil,
            targetID: UUID()
        )
    }

    func onTap(id: UUID, _ action: @escaping () -> Void) -> CKHitTargetView<Self> {
        CKHitTargetView(
            content: self,
            contentShape: nil,
            onHover: nil,
            onTap: action,
            onDrag: nil,
            targetID: id
        )
    }

    func onDrag(_ action: @escaping (CanvasDragPhase) -> Void) -> CKHitTargetView<Self> {
        CKHitTargetView(
            content: self,
            contentShape: nil,
            onHover: nil,
            onTap: nil,
            onDrag: action,
            targetID: UUID()
        )
    }

    func onDrag(id: UUID, _ action: @escaping (CanvasDragPhase) -> Void) -> CKHitTargetView<Self> {
        CKHitTargetView(
            content: self,
            contentShape: nil,
            onHover: nil,
            onTap: nil,
            onDrag: action,
            targetID: id
        )
    }
}

extension CKPathView {
    func hitTestPath(in context: RenderContext) -> CGPath {
        let path = path(in: context, style: defaultStyle)
        guard !path.isEmpty else { return CGMutablePath() }
        let padding = 4.0 / max(context.magnification, 0.001)
        let strokeWidth = max(defaultStyle.strokeWidth, 1.0) + padding
        let stroked = path.copy(
            strokingWithWidth: strokeWidth,
            lineCap: defaultStyle.lineCap.cgLineCap,
            lineJoin: defaultStyle.lineJoin.cgLineJoin,
            miterLimit: defaultStyle.miterLimit
        )
        if defaultStyle.fillColor != nil {
            let merged = CGMutablePath()
            merged.addPath(path)
            merged.addPath(stroked)
            return merged
        }
        return stroked
    }
}

extension CKHitTargetView {
    func contentShape(_ path: CGPath) -> CKHitTargetView<Content> {
        CKHitTargetView(
            content: content,
            contentShape: path,
            onHover: onHover,
            onTap: onTap,
            onDrag: onDrag,
            targetID: targetID
        )
    }

    func onHover(_ action: @escaping (Bool) -> Void) -> CKHitTargetView<Content> {
        CKHitTargetView(
            content: content,
            contentShape: contentShape,
            onHover: action,
            onTap: onTap,
            onDrag: onDrag,
            targetID: targetID
        )
    }

    func onTap(_ action: @escaping () -> Void) -> CKHitTargetView<Content> {
        CKHitTargetView(
            content: content,
            contentShape: contentShape,
            onHover: onHover,
            onTap: action,
            onDrag: onDrag,
            targetID: targetID
        )
    }

    func onDrag(_ action: @escaping (CanvasDragPhase) -> Void) -> CKHitTargetView<Content> {
        CKHitTargetView(
            content: content,
            contentShape: contentShape,
            onHover: onHover,
            onTap: onTap,
            onDrag: action,
            targetID: targetID
        )
    }
}

extension CKInteractionView {
    func hoverable(_ id: UUID) -> CKInteractionView<Content> {
        if targetID == id {
            var copy = self
            copy.isHoverable = true
            return copy
        }
        return CKInteractionView(
            content: content,
            targetID: id,
            isHoverable: true,
            isSelectable: isSelectable,
            isDraggable: isDraggable,
            contentShape: contentShape,
            dragPhaseHandler: dragPhaseHandler,
            dragDeltaHandler: dragDeltaHandler
        )
    }

    func selectable(_ id: UUID) -> CKInteractionView<Content> {
        if targetID == id {
            var copy = self
            copy.isSelectable = true
            return copy
        }
        return CKInteractionView(
            content: content,
            targetID: id,
            isHoverable: isHoverable,
            isSelectable: true,
            isDraggable: isDraggable,
            contentShape: contentShape,
            dragPhaseHandler: dragPhaseHandler,
            dragDeltaHandler: dragDeltaHandler
        )
    }

    func onDragGesture(_ action: @escaping (CanvasDragPhase) -> Void) -> CKInteractionView<Content> {
        var copy = self
        if let existing = copy.dragPhaseHandler {
            copy.dragPhaseHandler = { phase in
                existing(phase)
                action(phase)
            }
        } else {
            copy.dragPhaseHandler = action
        }
        return copy
    }

    func onDragGesture(_ action: @escaping (CanvasDragDelta) -> Void) -> CKInteractionView<Content> {
        var copy = self
        if let existing = copy.dragDeltaHandler {
            copy.dragDeltaHandler = { delta in
                existing(delta)
                action(delta)
            }
        } else {
            copy.dragDeltaHandler = action
        }
        return copy
    }

    func hoverable() -> CKInteractionView<Content> {
        var copy = self
        copy.isHoverable = true
        return copy
    }

    func selectable() -> CKInteractionView<Content> {
        var copy = self
        copy.isSelectable = true
        return copy
    }

    func draggable() -> CKInteractionView<Content> {
        var copy = self
        copy.isDraggable = true
        return copy
    }

    func contentShape(_ path: CGPath) -> CKInteractionView<Content> {
        var copy = self
        copy.contentShape = path
        return copy
    }
}

extension CKTransformView {
    func position(_ point: CGPoint) -> CKTransformView<Content> {
        var copy = self
        copy.position = point
        return copy
    }

    func position(x: CGFloat, y: CGFloat) -> CKTransformView<Content> {
        position(CGPoint(x: x, y: y))
    }

    func rotation(_ angle: CGFloat) -> CKTransformView<Content> {
        var copy = self
        copy.rotation = angle
        return copy
    }
}

extension CKStrokeView {
    func lineCap(_ lineCap: CAShapeLayerLineCap) -> CKStrokeView<Content> {
        var copy = self
        copy.lineCap = lineCap
        return copy
    }

    func lineJoin(_ lineJoin: CAShapeLayerLineJoin) -> CKStrokeView<Content> {
        var copy = self
        copy.lineJoin = lineJoin
        return copy
    }

    func miterLimit(_ limit: CGFloat) -> CKStrokeView<Content> {
        var copy = self
        copy.miterLimit = limit
        return copy
    }

    func lineDash(_ pattern: [CGFloat]) -> CKStrokeView<Content> {
        var copy = self
        copy.lineDash = pattern.map { NSNumber(value: Double($0)) }
        return copy
    }

    func clip(_ path: CGPath) -> CKStrokeView<Content> {
        var copy = self
        copy.clipPath = path
        return copy
    }

    func clip(to rect: CGRect) -> CKStrokeView<Content> {
        clip(CGPath(rect: rect, transform: nil))
    }
}

extension CKFillView {
    func clip(_ path: CGPath) -> CKFillView<Content> {
        var copy = self
        copy.clipPath = path
        return copy
    }

    func clip(to rect: CGRect) -> CKFillView<Content> {
        clip(CGPath(rect: rect, transform: nil))
    }
}

private extension DrawingPrimitive {
    var boundingBox: CGRect {
        switch self {
        case let .fill(path, _, _, _):
            return path.boundingBoxOfPath
        case let .stroke(path, _, lineWidth, _, _, _, _, _):
            let inset = lineWidth / 2
            return path.boundingBoxOfPath.insetBy(dx: -inset, dy: -inset)
        }
    }

    var path: CGPath? {
        switch self {
        case let .fill(path, _, _, _):
            return path
        case let .stroke(path, _, _, _, _, _, _, _):
            return path
        }
    }

    func withClip(_ clipPath: CGPath) -> DrawingPrimitive {
        switch self {
        case let .fill(path, color, rule, _):
            return .fill(path: path, color: color, rule: rule, clipPath: clipPath)
        case let .stroke(path, color, lineWidth, lineCap, lineJoin, miterLimit, lineDash, _):
            return .stroke(
                path: path,
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

private struct CKOpacityView: CKView {
    typealias Body = Never
    let content: AnyCKView
    let opacity: CGFloat

    var body: Never {
        fatalError("CKOpacityView has no body.")
    }

    func _render(in context: RenderContext) -> [DrawingPrimitive] {
        let value = opacity.clamped(to: 0...1)
        return content._render(in: context).map { $0.applyingOpacity(value) }
    }
}

extension CKView {
    func opacity(_ value: CGFloat) -> some CKView {
        CKOpacityView(content: AnyCKView(self), opacity: value)
    }
}

extension DrawingPrimitive {
    func applyingOpacity(_ opacity: CGFloat) -> DrawingPrimitive {
        switch self {
        case let .fill(path, color, rule, clipPath):
            return .fill(
                path: path,
                color: color.applyingOpacity(opacity),
                rule: rule,
                clipPath: clipPath
            )
        case let .stroke(path, color, lineWidth, lineCap, lineJoin, miterLimit, lineDash, clipPath):
            return .stroke(
                path: path,
                color: color.applyingOpacity(opacity),
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

private extension CAShapeLayerLineCap {
    var cgLineCap: CGLineCap {
        switch self {
        case .butt:
            return .butt
        case .round:
            return .round
        case .square:
            return .square
        default:
            return .butt
        }
    }
}

private extension CAShapeLayerLineJoin {
    var cgLineJoin: CGLineJoin {
        switch self {
        case .miter:
            return .miter
        case .round:
            return .round
        case .bevel:
            return .bevel
        default:
            return .miter
        }
    }
}
