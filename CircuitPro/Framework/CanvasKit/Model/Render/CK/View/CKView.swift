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

struct CKStyleModifier<Content: CKView>: CKView {
    typealias Body = CKGroup

    let content: Content
    let apply: (inout CKStyleState) -> Void
    let applyNode: ((inout CKRenderNode) -> Void)?

    var body: CKGroup {
        .empty
    }

    init(
        content: Content,
        apply: @escaping (inout CKStyleState) -> Void,
        applyNode: ((inout CKRenderNode) -> Void)? = nil
    ) {
        self.content = content
        self.apply = apply
        self.applyNode = applyNode
    }

    func makeNode(in context: RenderContext) -> CKRenderNode? {
        guard var node = content.makeNode(in: context) else {
            return nil
        }
        apply(&node.style)
        applyNode?(&node)
        return node
    }

    func update(_ extra: @escaping (inout CKStyleState) -> Void) -> CKStyleModifier<Content> {
        let currentApply = apply
        let currentNodeApply = applyNode
        return CKStyleModifier(
            content: content,
            apply: { style in
                currentApply(&style)
                extra(&style)
            },
            applyNode: currentNodeApply
        )
    }

    func updateNode(_ extra: @escaping (inout CKRenderNode) -> Void) -> CKStyleModifier<Content> {
        let currentApply = apply
        let currentNodeApply = applyNode
        return CKStyleModifier(
            content: content,
            apply: currentApply,
            applyNode: { node in
                currentNodeApply?(&node)
                extra(&node)
            }
        )
    }
}

struct CKInteractionModifier<Content: CKView>: CKView {
    typealias Body = CKGroup

    let content: Content
    let targetID: UUID
    let apply: (inout CKInteractionState) -> Void

    var body: CKGroup {
        .empty
    }

    init(
        content: Content,
        targetID: UUID,
        apply: @escaping (inout CKInteractionState) -> Void
    ) {
        self.content = content
        self.targetID = targetID
        self.apply = apply
    }

    func makeNode(in context: RenderContext) -> CKRenderNode? {
        guard var node = content.makeNode(in: context) else {
            return nil
        }
        var interaction = node.interaction ?? CKInteractionState(
            id: targetID,
            hoverable: false,
            selectable: false,
            draggable: false,
            contentShape: nil,
            hitTestPriority: 0,
            onDragPhase: nil,
            onDragDelta: nil,
            onHover: nil,
            onTap: nil,
            onDrag: nil
        )
        if interaction.id != targetID {
            interaction.id = targetID
        }
        apply(&interaction)
        node.interaction = interaction
        return node
    }

    func update(_ extra: @escaping (inout CKInteractionState) -> Void) -> CKInteractionModifier<Content> {
        let currentApply = apply
        return CKInteractionModifier(content: content, targetID: targetID) { state in
            currentApply(&state)
            extra(&state)
        }
    }

    func update(id: UUID, _ extra: @escaping (inout CKInteractionState) -> Void) -> CKInteractionModifier<Content> {
        let currentApply = apply
        return CKInteractionModifier(content: content, targetID: id) { state in
            currentApply(&state)
            extra(&state)
        }
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

    func mergePaths() -> CKStyleModifier<Self> {
        style { _ in }
            .updateNode { node in
                node.mergeChildPaths = true
            }
    }

    func style(_ apply: @escaping (inout CKStyleState) -> Void) -> CKStyleModifier<Self> {
        CKStyleModifier(content: self, apply: apply)
    }

    func interaction(_ apply: @escaping (inout CKInteractionState) -> Void) -> CKInteractionModifier<Self> {
        CKInteractionModifier(content: self, targetID: UUID(), apply: apply)
    }

    func interaction(id: UUID, _ apply: @escaping (inout CKInteractionState) -> Void) -> CKInteractionModifier<Self> {
        CKInteractionModifier(content: self, targetID: id, apply: apply)
    }

    func stroke(_ color: CGColor, width: CGFloat = 1.0) -> CKStyleModifier<Self> {
        style { style in
            style.stroke = CKStrokeStyle(
                color: color,
                width: width,
                lineCap: .round,
                lineJoin: .miter,
                miterLimit: 10,
                lineDash: nil
            )
        }
    }

    func stroke(_ color: CKColor, width: CGFloat = 1.0) -> CKStyleModifier<Self> {
        stroke(color.cgColor, width: width)
    }

    func fill(_ color: CGColor) -> CKStyleModifier<Self> {
        let rule = (self as? CKCompositeRuleProvider)?.compositeRule ?? .nonZero
        return style { style in
            style.fill = CKFillStyle(color: color, rule: rule)
        }
        .updateNode { node in
            node.renderChildren = false
        }
    }

    func fill(_ color: CKColor) -> CKStyleModifier<Self> {
        fill(color.cgColor)
    }

    func fill(_ color: CGColor, rule: CAShapeLayerFillRule) -> CKStyleModifier<Self> {
        style { style in
            style.fill = CKFillStyle(color: color, rule: rule)
        }
        .updateNode { node in
            node.renderChildren = false
        }
    }

    func fill(_ color: CKColor, rule: CAShapeLayerFillRule) -> CKStyleModifier<Self> {
        fill(color.cgColor, rule: rule)
    }

    func halo(_ color: CGColor, width: CGFloat) -> CKStyleModifier<Self> {
        style { style in
            style.halos.append(CKHalo(color: color, width: width))
        }
    }

    func halo(_ color: CKColor, width: CGFloat) -> CKStyleModifier<Self> {
        halo(color.cgColor, width: width)
    }

    func excludeFromPaths() -> CKNoPathView<Self> {
        CKNoPathView(content: self)
    }

    func color(_ color: CKColor) -> CKStyleModifier<Self> {
        style { style in
            style.colorOverride = color.cgColor
        }
    }

    func clip(_ path: CGPath) -> CKStyleModifier<Self> {
        style { style in
            style.clipPath = path
        }
    }

    func clip(to rect: CGRect) -> CKStyleModifier<Self> {
        clip(CGPath(rect: rect, transform: nil))
    }

    func composite(
        rule: CAShapeLayerFillRule = .nonZero,
        @CKViewBuilder _ content: () -> CKGroup
    ) -> CKCompositeView<Self, CKGroup> {
        CKCompositeView(content: self, composite: content(), rule: rule)
    }

    func hoverable(_ id: UUID) -> CKInteractionModifier<Self> {
        interaction(id: id) { state in
            state.hoverable = true
        }
    }

    func selectable(_ id: UUID) -> CKInteractionModifier<Self> {
        interaction(id: id) { state in
            state.selectable = true
        }
    }

    func onDragGesture(_ action: @escaping (CanvasDragPhase) -> Void) -> CKInteractionModifier<Self> {
        onDragGesture { phase, _ in
            action(phase)
        }
    }

    func onDragGesture(_ action: @escaping (CanvasDragPhase, CanvasDragSession) -> Void) -> CKInteractionModifier<Self> {
        interaction { state in
            state.onDragPhase = action
        }
    }

    func onDragGesture(_ action: @escaping (CanvasDragDelta) -> Void) -> CKInteractionModifier<Self> {
        onDragGesture { delta, _ in
            action(delta)
        }
    }

    func onDragGesture(_ action: @escaping (CanvasDragDelta, CanvasDragSession) -> Void) -> CKInteractionModifier<Self> {
        interaction { state in
            state.onDragDelta = action
        }
    }

    func onCanvasDrag(
        _ action: @escaping (CanvasGlobalDragPhase, RenderContext, CanvasController) -> Void
    ) -> CKCanvasDragView<Self> {
        CKCanvasDragView(
            content: self,
            dragHandler: CanvasGlobalDragHandler(id: UUID(), handler: action)
        )
    }

    func contentShape(_ path: CGPath) -> CKInteractionModifier<Self> {
        interaction { state in
            state.contentShape = path
        }
    }

    func contentShape(_ path: CGPath, id: UUID) -> CKInteractionModifier<Self> {
        interaction(id: id) { state in
            state.contentShape = path
        }
    }

    func onHover(_ action: @escaping (Bool) -> Void) -> CKInteractionModifier<Self> {
        interaction { state in
            state.onHover = action
            state.hoverable = true
        }
    }

    func onHover(id: UUID, _ action: @escaping (Bool) -> Void) -> CKInteractionModifier<Self> {
        interaction(id: id) { state in
            state.onHover = action
            state.hoverable = true
        }
    }

    func onTap(_ action: @escaping () -> Void) -> CKInteractionModifier<Self> {
        interaction { state in
            state.onTap = action
            state.selectable = true
        }
    }

    func onTap(id: UUID, _ action: @escaping () -> Void) -> CKInteractionModifier<Self> {
        interaction(id: id) { state in
            state.onTap = action
            state.selectable = true
        }
    }

    func onDrag(_ action: @escaping (CanvasDragPhase) -> Void) -> CKInteractionModifier<Self> {
        onDrag { phase, _ in
            action(phase)
        }
    }

    func onDrag(_ action: @escaping (CanvasDragPhase, CanvasDragSession) -> Void) -> CKInteractionModifier<Self> {
        interaction { state in
            state.onDrag = action
            state.draggable = true
        }
    }

    func onDrag(id: UUID, _ action: @escaping (CanvasDragPhase) -> Void) -> CKInteractionModifier<Self> {
        onDrag(id: id) { phase, _ in
            action(phase)
        }
    }

    func onDrag(id: UUID, _ action: @escaping (CanvasDragPhase, CanvasDragSession) -> Void) -> CKInteractionModifier<Self> {
        interaction(id: id) { state in
            state.onDrag = action
            state.draggable = true
        }
    }
}

extension CKInteractionModifier {
    func hoverable(_ id: UUID) -> CKInteractionModifier<Content> {
        if targetID == id {
            return update { state in
                state.hoverable = true
            }
        }
        return update(id: id) { state in
            state.hoverable = true
        }
    }

    func selectable(_ id: UUID) -> CKInteractionModifier<Content> {
        if targetID == id {
            return update { state in
                state.selectable = true
            }
        }
        return update(id: id) { state in
            state.selectable = true
        }
    }

    func onDragGesture(_ action: @escaping (CanvasDragPhase) -> Void) -> CKInteractionModifier<Content> {
        onDragGesture { phase, _ in
            action(phase)
        }
    }

    func onDragGesture(_ action: @escaping (CanvasDragPhase, CanvasDragSession) -> Void) -> CKInteractionModifier<Content> {
        update { state in
            if let existing = state.onDragPhase {
                state.onDragPhase = { phase, session in
                    existing(phase, session)
                    action(phase, session)
                }
            } else {
                state.onDragPhase = action
            }
        }
    }

    func onDragGesture(_ action: @escaping (CanvasDragDelta) -> Void) -> CKInteractionModifier<Content> {
        onDragGesture { delta, _ in
            action(delta)
        }
    }

    func onDragGesture(_ action: @escaping (CanvasDragDelta, CanvasDragSession) -> Void) -> CKInteractionModifier<Content> {
        update { state in
            if let existing = state.onDragDelta {
                state.onDragDelta = { delta, session in
                    existing(delta, session)
                    action(delta, session)
                }
            } else {
                state.onDragDelta = action
            }
        }
    }

    func hoverable() -> CKInteractionModifier<Content> {
        update { state in
            state.hoverable = true
        }
    }

    func selectable() -> CKInteractionModifier<Content> {
        update { state in
            state.selectable = true
        }
    }

    func draggable() -> CKInteractionModifier<Content> {
        update { state in
            state.draggable = true
        }
    }

    func contentShape(_ path: CGPath) -> CKInteractionModifier<Content> {
        update { state in
            state.contentShape = path
        }
    }

    func contentShape(_ path: CGPath, id: UUID) -> CKInteractionModifier<Content> {
        update(id: id) { state in
            state.contentShape = path
        }
    }

    func hitTestPriority(_ priority: Int) -> CKInteractionModifier<Content> {
        update { state in
            state.hitTestPriority = priority
        }
    }

    func onHover(_ action: @escaping (Bool) -> Void) -> CKInteractionModifier<Content> {
        update { state in
            state.onHover = action
            state.hoverable = true
        }
    }

    func onHover(id: UUID, _ action: @escaping (Bool) -> Void) -> CKInteractionModifier<Content> {
        update(id: id) { state in
            state.onHover = action
            state.hoverable = true
        }
    }

    func onTap(_ action: @escaping () -> Void) -> CKInteractionModifier<Content> {
        update { state in
            state.onTap = action
            state.selectable = true
        }
    }

    func onTap(id: UUID, _ action: @escaping () -> Void) -> CKInteractionModifier<Content> {
        update(id: id) { state in
            state.onTap = action
            state.selectable = true
        }
    }

    func onDrag(_ action: @escaping (CanvasDragPhase) -> Void) -> CKInteractionModifier<Content> {
        onDrag { phase, _ in
            action(phase)
        }
    }

    func onDrag(_ action: @escaping (CanvasDragPhase, CanvasDragSession) -> Void) -> CKInteractionModifier<Content> {
        update { state in
            state.onDrag = action
            state.draggable = true
        }
    }

    func onDrag(id: UUID, _ action: @escaping (CanvasDragPhase) -> Void) -> CKInteractionModifier<Content> {
        onDrag(id: id) { phase, _ in
            action(phase)
        }
    }

    func onDrag(id: UUID, _ action: @escaping (CanvasDragPhase, CanvasDragSession) -> Void) -> CKInteractionModifier<Content> {
        update(id: id) { state in
            state.onDrag = action
            state.draggable = true
        }
    }
}

extension CKStyleModifier {
    func lineCap(_ lineCap: CAShapeLayerLineCap) -> CKStyleModifier<Content> {
        update { style in
            style.stroke?.lineCap = lineCap
        }
    }

    func lineJoin(_ lineJoin: CAShapeLayerLineJoin) -> CKStyleModifier<Content> {
        update { style in
            style.stroke?.lineJoin = lineJoin
        }
    }

    func miterLimit(_ limit: CGFloat) -> CKStyleModifier<Content> {
        update { style in
            style.stroke?.miterLimit = limit
        }
    }

    func lineDash(_ pattern: [CGFloat]) -> CKStyleModifier<Content> {
        update { style in
            style.stroke?.lineDash = pattern.map { NSNumber(value: Double($0)) }
        }
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


extension CKView {
    func opacity(_ value: CGFloat) -> CKStyleModifier<Self> {
        style { style in
            style.opacity *= value
        }
    }
}
