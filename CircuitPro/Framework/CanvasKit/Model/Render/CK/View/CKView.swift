import AppKit

protocol CKView {
    associatedtype Body: CKView
    @CKViewBuilder var body: Body { get }
    func makeNode(in context: RenderContext) -> CKRenderNode?
}

protocol CKNodeView: CKView {}

extension CKNodeView {
    var body: CKGroup {
        .empty
    }
}

struct CKInteractionView<Content: CKView>: CKView {
    typealias Body = CKGroup

    let content: Content
    let targetID: UUID
    var isHoverable: Bool
    var isSelectable: Bool
    var isDraggable: Bool
    var contentShape: CGPath?
    var hitTestPriority: Int
    var dragPhaseHandler: ((CanvasDragPhase, CanvasDragSession) -> Void)?
    var dragDeltaHandler: ((CanvasDragDelta, CanvasDragSession) -> Void)?

    var body: CKGroup {
        .empty
    }

    init(
        content: Content,
        targetID: UUID,
        isHoverable: Bool,
        isSelectable: Bool,
        isDraggable: Bool,
        contentShape: CGPath?,
        hitTestPriority: Int = 0,
        dragPhaseHandler: ((CanvasDragPhase, CanvasDragSession) -> Void)?,
        dragDeltaHandler: ((CanvasDragDelta, CanvasDragSession) -> Void)?
    ) {
        self.content = content
        self.targetID = targetID
        self.isHoverable = isHoverable
        self.isSelectable = isSelectable
        self.isDraggable = isDraggable
        self.contentShape = contentShape
        self.hitTestPriority = hitTestPriority
        self.dragPhaseHandler = dragPhaseHandler
        self.dragDeltaHandler = dragDeltaHandler
    }

}

extension CKInteractionView: CKNodeView {
    func makeNode(in context: RenderContext) -> CKRenderNode? {
        guard let child = content.makeNode(in: context) else {
            return nil
        }
        let interaction = CKInteractionState(
            id: targetID,
            hoverable: isHoverable,
            selectable: isSelectable,
            draggable: isDraggable,
            contentShape: contentShape,
            hitTestPriority: hitTestPriority,
            onDragPhase: dragPhaseHandler,
            onDragDelta: dragDeltaHandler,
            onHover: nil,
            onTap: nil,
            onDrag: nil
        )
        var node = child
        node.interaction = interaction
        return node
    }
}

struct CKCanvasDragView<Content: CKView>: CKView {
    typealias Body = CKGroup

    let content: Content
    let dragHandler: CanvasGlobalDragHandler

    var body: CKGroup {
        .empty
    }
}

extension CKCanvasDragView: CKNodeView {
    func makeNode(in context: RenderContext) -> CKRenderNode? {
        guard let child = content.makeNode(in: context) else {
            return nil
        }
        return CKRenderNode(
            geometry: .group,
            children: [child],
            renderChildren: true,
            canvasDragHandler: dragHandler
        )
    }
}

extension CKView {
    func makeNode(in context: RenderContext) -> CKRenderNode? {
        body.makeNode(in: context)
    }
}

private protocol CKCompositeRuleProvider {
    var compositeRule: CAShapeLayerFillRule { get }
}

struct CKComposite: CKView {
    typealias Body = CKGroup

    let rule: CAShapeLayerFillRule
    let content: CKGroup

    init(rule: CAShapeLayerFillRule = .nonZero, @CKViewBuilder _ content: () -> CKGroup) {
        self.rule = rule
        self.content = content()
    }

    var body: CKGroup {
        .empty
    }
}

extension CKComposite: CKNodeView {
    func makeNode(in context: RenderContext) -> CKRenderNode? {
        guard let node = content.makeNode(in: context) else {
            return nil
        }
        var compositeNode = node
        compositeNode.mergeChildPaths = true
        compositeNode.renderChildren = false
        return compositeNode
    }
}

extension CKComposite: CKCompositeRuleProvider {
    var compositeRule: CAShapeLayerFillRule {
        rule
    }
}

struct CKTransformView<Content: CKView>: CKView {
    typealias Body = CKGroup

    let content: Content
    var position: CGPoint?
    var rotation: CGFloat

    var body: CKGroup {
        .empty
    }
}

extension CKTransformView: CKNodeView {
    func makeNode(in context: RenderContext) -> CKRenderNode? {
        guard let child = content.makeNode(in: context) else {
            return nil
        }
        var node = child
        if let position {
            node.transformState.position.x += position.x
            node.transformState.position.y += position.y
        }
        if rotation != 0 {
            node.transformState.rotation += rotation
        }
        return node
    }
}

extension CKTransformView: CKCompositeRuleProvider where Content: CKCompositeRuleProvider {
    var compositeRule: CAShapeLayerFillRule {
        content.compositeRule
    }
}

struct CKStrokeView<Content: CKView>: CKView {
    typealias Body = CKGroup

    let content: Content
    var color: CGColor
    var width: CGFloat
    var lineCap: CAShapeLayerLineCap = .round
    var lineJoin: CAShapeLayerLineJoin = .miter
    var miterLimit: CGFloat = 10
    var lineDash: [NSNumber]?
    var clipPath: CGPath?

    var body: CKGroup {
        .empty
    }
}

extension CKStrokeView: CKNodeView {
    func makeNode(in context: RenderContext) -> CKRenderNode? {
        guard let child = content.makeNode(in: context) else {
            return nil
        }
        let stroke = CKStrokeStyle(
            color: color,
            width: width,
            lineCap: lineCap,
            lineJoin: lineJoin,
            miterLimit: miterLimit,
            lineDash: lineDash
        )
        var node = child
        node.style.stroke = stroke
        return node
    }
}

struct CKFillView<Content: CKView>: CKView {
    typealias Body = CKGroup

    let content: Content
    var color: CGColor
    var rule: CAShapeLayerFillRule = .nonZero
    var clipPath: CGPath?

    var body: CKGroup {
        .empty
    }
}

extension CKFillView: CKNodeView {
    func makeNode(in context: RenderContext) -> CKRenderNode? {
        guard let child = content.makeNode(in: context) else {
            return nil
        }
        let fill = CKFillStyle(color: color, rule: rule)
        var node = child
        node.style.fill = fill
        node.renderChildren = false
        return node
    }
}

struct CKHaloView<Content: CKView>: CKView {
    typealias Body = CKGroup

    let content: Content
    var color: CGColor
    var width: CGFloat

    var body: CKGroup {
        .empty
    }
}

extension CKHaloView: CKNodeView {
    func makeNode(in context: RenderContext) -> CKRenderNode? {
        guard let child = content.makeNode(in: context) else {
            return nil
        }
        var node = child
        node.style.halos.append(CKHalo(color: color, width: width))
        return node
    }
}

struct CKClipView<Content: CKView>: CKView {
    typealias Body = CKGroup

    let content: Content
    var clipPath: CGPath

    var body: CKGroup {
        .empty
    }
}

extension CKClipView: CKNodeView {
    func makeNode(in context: RenderContext) -> CKRenderNode? {
        guard let child = content.makeNode(in: context) else {
            return nil
        }
        var node = child
        node.style.clipPath = clipPath
        return node
    }
}

struct CKNoPathView<Content: CKView>: CKView {
    typealias Body = CKGroup

    let content: Content

    var body: CKGroup {
        .empty
    }
}

extension CKNoPathView: CKNodeView {
    func makeNode(in context: RenderContext) -> CKRenderNode? {
        guard let child = content.makeNode(in: context) else {
            return nil
        }
        var node = child
        node.excludesFromHitPath = true
        return node
    }
}

struct CKColorOverrideView<Content: CKView>: CKView {
    typealias Body = CKGroup

    let content: Content
    let color: CKColor

    var body: CKGroup {
        .empty
    }
}

extension CKColorOverrideView: CKNodeView {
    func makeNode(in context: RenderContext) -> CKRenderNode? {
        guard let child = content.makeNode(in: context) else {
            return nil
        }
        var node = child
        node.style.colorOverride = color.cgColor
        return node
    }
}

struct CKCompositeView<Content: CKView, Composite: CKView>: CKView {
    typealias Body = CKGroup

    let content: Content
    let composite: Composite
    let rule: CAShapeLayerFillRule

    var body: CKGroup {
        .empty
    }
}

extension CKCompositeView: CKNodeView {
    func makeNode(in context: RenderContext) -> CKRenderNode? {
        guard let base = content.makeNode(in: context),
              let overlay = composite.makeNode(in: context)
        else { return nil }
        let node = CKRenderNode(
            geometry: .group,
            children: [base, overlay],
            renderChildren: false,
            mergeChildPaths: true
        )
        return node
    }
}

extension CKCompositeView: CKCompositeRuleProvider {
    var compositeRule: CAShapeLayerFillRule {
        rule
    }
}

struct CKHitTargetView<Content: CKView>: CKView {
    typealias Body = CKGroup

    let content: Content
    let contentShape: CGPath?
    let onHover: ((Bool) -> Void)?
    let onTap: (() -> Void)?
    let onDrag: ((CanvasDragPhase, CanvasDragSession) -> Void)?
    let targetID: UUID
    let hitTestPriority: Int

    var body: CKGroup {
        .empty
    }

    init(
        content: Content,
        contentShape: CGPath?,
        onHover: ((Bool) -> Void)?,
        onTap: (() -> Void)?,
        onDrag: ((CanvasDragPhase, CanvasDragSession) -> Void)?,
        targetID: UUID,
        hitTestPriority: Int = 0
    ) {
        self.content = content
        self.contentShape = contentShape
        self.onHover = onHover
        self.onTap = onTap
        self.onDrag = onDrag
        self.targetID = targetID
        self.hitTestPriority = hitTestPriority
    }

}

extension CKHitTargetView: CKNodeView {
    func makeNode(in context: RenderContext) -> CKRenderNode? {
        guard let child = content.makeNode(in: context) else {
            return nil
        }
        let interaction = CKInteractionState(
            id: targetID,
            hoverable: onHover != nil,
            selectable: onTap != nil,
            draggable: onDrag != nil,
            contentShape: contentShape,
            hitTestPriority: hitTestPriority,
            onDragPhase: nil,
            onDragDelta: nil,
            onHover: onHover,
            onTap: onTap,
            onDrag: onDrag
        )
        var node = child
        node.interaction = interaction
        return node
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

    func stroke(_ color: CKColor, width: CGFloat = 1.0) -> CKStrokeView<Self> {
        stroke(color.cgColor, width: width)
    }

    func fill(_ color: CGColor) -> CKFillView<Self> {
        let rule = (self as? CKCompositeRuleProvider)?.compositeRule ?? .nonZero
        return CKFillView(content: self, color: color, rule: rule)
    }

    func fill(_ color: CKColor) -> CKFillView<Self> {
        fill(color.cgColor)
    }

    func fill(_ color: CGColor, rule: CAShapeLayerFillRule) -> CKFillView<Self> {
        CKFillView(content: self, color: color, rule: rule)
    }

    func fill(_ color: CKColor, rule: CAShapeLayerFillRule) -> CKFillView<Self> {
        fill(color.cgColor, rule: rule)
    }

    func halo(_ color: CGColor, width: CGFloat) -> CKHaloView<Self> {
        CKHaloView(content: self, color: color, width: width)
    }

    func halo(_ color: CKColor, width: CGFloat) -> CKHaloView<Self> {
        halo(color.cgColor, width: width)
    }

    func excludeFromPaths() -> CKNoPathView<Self> {
        CKNoPathView(content: self)
    }

    func color(_ color: CKColor) -> CKColorOverrideView<Self> {
        CKColorOverrideView(content: self, color: color)
    }

    func clip(_ path: CGPath) -> CKClipView<Self> {
        CKClipView(content: self, clipPath: path)
    }

    func clip(to rect: CGRect) -> CKClipView<Self> {
        CKClipView(content: self, clipPath: CGPath(rect: rect, transform: nil))
    }

    func composite(
        rule: CAShapeLayerFillRule = .nonZero,
        @CKViewBuilder _ content: () -> CKGroup
    ) -> CKCompositeView<Self, CKGroup> {
        CKCompositeView(content: self, composite: content(), rule: rule)
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
        onDragGesture { phase, _ in
            action(phase)
        }
    }

    func onDragGesture(_ action: @escaping (CanvasDragPhase, CanvasDragSession) -> Void) -> CKInteractionView<Self> {
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
        onDragGesture { delta, _ in
            action(delta)
        }
    }

    func onDragGesture(_ action: @escaping (CanvasDragDelta, CanvasDragSession) -> Void) -> CKInteractionView<Self> {
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

    func onCanvasDrag(
        _ action: @escaping (CanvasGlobalDragPhase, RenderContext, CanvasController) -> Void
    ) -> CKCanvasDragView<Self> {
        CKCanvasDragView(
            content: self,
            dragHandler: CanvasGlobalDragHandler(id: UUID(), handler: action)
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
        onDrag { phase, _ in
            action(phase)
        }
    }

    func onDrag(_ action: @escaping (CanvasDragPhase, CanvasDragSession) -> Void) -> CKHitTargetView<Self> {
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
        onDrag(id: id) { phase, _ in
            action(phase)
        }
    }

    func onDrag(id: UUID, _ action: @escaping (CanvasDragPhase, CanvasDragSession) -> Void) -> CKHitTargetView<Self> {
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

extension CKHitTargetView {
    func contentShape(_ path: CGPath) -> CKHitTargetView<Content> {
        CKHitTargetView(
            content: content,
            contentShape: path,
            onHover: onHover,
            onTap: onTap,
            onDrag: onDrag,
            targetID: targetID,
            hitTestPriority: hitTestPriority
        )
    }

    func onHover(_ action: @escaping (Bool) -> Void) -> CKHitTargetView<Content> {
        CKHitTargetView(
            content: content,
            contentShape: contentShape,
            onHover: action,
            onTap: onTap,
            onDrag: onDrag,
            targetID: targetID,
            hitTestPriority: hitTestPriority
        )
    }

    func onTap(_ action: @escaping () -> Void) -> CKHitTargetView<Content> {
        CKHitTargetView(
            content: content,
            contentShape: contentShape,
            onHover: onHover,
            onTap: action,
            onDrag: onDrag,
            targetID: targetID,
            hitTestPriority: hitTestPriority
        )
    }

    func onDrag(_ action: @escaping (CanvasDragPhase) -> Void) -> CKHitTargetView<Content> {
        onDrag { phase, _ in
            action(phase)
        }
    }

    func onDrag(_ action: @escaping (CanvasDragPhase, CanvasDragSession) -> Void) -> CKHitTargetView<Content> {
        CKHitTargetView(
            content: content,
            contentShape: contentShape,
            onHover: onHover,
            onTap: onTap,
            onDrag: action,
            targetID: targetID,
            hitTestPriority: hitTestPriority
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
            hitTestPriority: hitTestPriority,
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
            hitTestPriority: hitTestPriority,
            dragPhaseHandler: dragPhaseHandler,
            dragDeltaHandler: dragDeltaHandler
        )
    }

    func onDragGesture(_ action: @escaping (CanvasDragPhase) -> Void) -> CKInteractionView<Content> {
        onDragGesture { phase, _ in
            action(phase)
        }
    }

    func onDragGesture(_ action: @escaping (CanvasDragPhase, CanvasDragSession) -> Void) -> CKInteractionView<Content> {
        var copy = self
        if let existing = copy.dragPhaseHandler {
            copy.dragPhaseHandler = { phase, session in
                existing(phase, session)
                action(phase, session)
            }
        } else {
            copy.dragPhaseHandler = action
        }
        return copy
    }

    func onDragGesture(_ action: @escaping (CanvasDragDelta) -> Void) -> CKInteractionView<Content> {
        onDragGesture { delta, _ in
            action(delta)
        }
    }

    func onDragGesture(_ action: @escaping (CanvasDragDelta, CanvasDragSession) -> Void) -> CKInteractionView<Content> {
        var copy = self
        if let existing = copy.dragDeltaHandler {
            copy.dragDeltaHandler = { delta, session in
                existing(delta, session)
                action(delta, session)
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

    func hitTestPriority(_ priority: Int) -> CKInteractionView<Content> {
        var copy = self
        copy.hitTestPriority = priority
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
    typealias Body = CKGroup
    let content: AnyCKView
    let opacity: CGFloat

    var body: CKGroup {
        .empty
    }
}

extension CKOpacityView: CKNodeView {
    func makeNode(in context: RenderContext) -> CKRenderNode? {
        guard let child = content.makeNode(in: context) else {
            return nil
        }
        var node = child
        node.style.opacity *= opacity
        return node
    }
}

extension CKView {
    func opacity(_ value: CGFloat) -> some CKView {
        CKOpacityView(content: AnyCKView(self), opacity: value)
    }
}
