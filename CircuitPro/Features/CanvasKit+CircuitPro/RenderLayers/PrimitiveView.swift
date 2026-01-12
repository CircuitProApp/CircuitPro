import AppKit

struct PrimitiveView: CKView {
    @CKContext var context
    let primitive: CanvasItemRef<AnyCanvasPrimitive>

    var showHalo: Bool {
        context.highlightedItemIDs.contains(primitive.id) ||
            context.selectedItemIDs.contains(primitive.id)
    }

    var body: some CKView {
        let dragState = context.environment.handleDragState
        CKGroup {
            CKGroup {
                switch primitive.value {
                case .rectangle(let rect):
                    CKRectangle(cornerRadius: rect.cornerRadius)
                        .frame(width: rect.size.width, height: rect.size.height)
                case .circle(let circle):
                    CKCircle(radius: circle.radius)


                case .line(let line):
                    CKLine(length: line.length, direction: .horizontal)
                }
            }
            .fill(primitive.value.filled ? primitive.value.color?.cgColor ?? .white : .clear)
            .stroke(primitive.value.color?.cgColor ?? .white, width: primitive.value.strokeWidth)
            .halo(showHalo ? .white.haloOpacity() : .clear, width: 5.0)

            CKGroup {
                switch primitive.value {
                case .rectangle(let rect):
                    let halfW = rect.size.width / 2
                    let halfH = rect.size.height / 2

                    HandleView()
                        .position(x: -halfW, y: halfH)
                        .onDragGesture { phase in
                            updateRectangleHandle(.rectTopLeft, phase: phase, dragState: dragState)
                        }
                        .hitTestPriority(10)
                    HandleView()
                        .position(x: halfW, y: halfH)
                        .onDragGesture { phase in
                            updateRectangleHandle(.rectTopRight, phase: phase, dragState: dragState)
                        }
                        .hitTestPriority(10)
                    HandleView()
                        .position(x: halfW, y: -halfH)
                        .onDragGesture { phase in
                            updateRectangleHandle(.rectBottomRight, phase: phase, dragState: dragState)
                        }
                        .hitTestPriority(10)
                    HandleView()
                        .position(x: -halfW, y: -halfH)
                        .onDragGesture { phase in
                            updateRectangleHandle(.rectBottomLeft, phase: phase, dragState: dragState)
                        }
                        .hitTestPriority(10)
                case .circle(let circle):
                    let r = circle.radius
                    HandleView()
                        .position(x: r, y: 0)
                        .onDragGesture { phase in
                            updateCircleHandle(phase)
                        }
                        .hitTestPriority(10)

                case .line(let line):
                    let half = line.length / 2
                    HandleView()
                        .position(x: -half, y: 0)
                        .onDragGesture { phase in
                            updateLineHandle(.lineStart, phase: phase, dragState: dragState)
                        }
                        .hitTestPriority(10)
                    HandleView()
                        .position(x: half, y: 0)
                        .onDragGesture { phase in
                            updateLineHandle(.lineEnd, phase: phase, dragState: dragState)
                        }
                        .hitTestPriority(10)

                }
            }
        }
        .position(primitive.value.position)
        .rotation(primitive.value.rotation)
    }

    private func updateCircleHandle(_ phase: CanvasDragPhase) {
        guard case .changed(let delta) = phase else { return }
        primitive.update { prim in
            guard case .circle(var circle) = prim else { return }
            let center = circle.position
            let world = CGPoint(
                x: delta.processedLocation.x - center.x,
                y: delta.processedLocation.y - center.y
            )
            circle.radius = max(hypot(world.x, world.y), 1)
            circle.rotation = atan2(world.y, world.x)
            prim = .circle(circle)
        }
    }

    private func updateLineHandle(
        _ kind: CanvasHandle.Kind,
        phase: CanvasDragPhase,
        dragState: CanvasHandleDragState
    ) {
        switch phase {
        case .began:
            guard case .line(let line) = primitive.value else { return }
            let oppositeWorld = (kind == .lineStart) ? line.endPoint : line.startPoint
            dragState.begin(ownerID: primitive.id, kind: kind, oppositeWorld: oppositeWorld)
        case .changed(let delta):
            guard case .line(let line) = primitive.value else { return }
            guard let oppositeWorld = dragState.oppositeWorld(ownerID: primitive.id, kind: kind) else { return }
            let dragWorld = delta.processedLocation
            let worldToLocal = CGAffineTransform(translationX: line.position.x, y: line.position.y)
                .rotated(by: line.rotation)
                .inverted()
            let dragLocal = dragWorld.applying(worldToLocal)
            let oppositeLocal = oppositeWorld.applying(worldToLocal)
            primitive.update { prim in
                prim.updateHandle(kind, to: dragLocal, opposite: oppositeLocal)
            }
        case .ended:
            dragState.end(ownerID: primitive.id, kind: kind)
        }
    }

    private func updateRectangleHandle(
        _ kind: CanvasHandle.Kind,
        phase: CanvasDragPhase,
        dragState: CanvasHandleDragState
    ) {
        switch phase {
        case .began:
            guard case .rectangle(let rect) = primitive.value else { return }
            let halfW = rect.size.width / 2
            let halfH = rect.size.height / 2
            let oppositeLocal = rectHandleLocal(
                kind: kind.opposite ?? kind,
                halfW: halfW,
                halfH: halfH
            )
            let oppositeWorld = toWorld(oppositeLocal, position: rect.position, rotation: rect.rotation)
            dragState.begin(ownerID: primitive.id, kind: kind, oppositeWorld: oppositeWorld)
        case .changed(let delta):
            guard case .rectangle(let rect) = primitive.value else { return }
            guard let oppositeWorld = dragState.oppositeWorld(ownerID: primitive.id, kind: kind) else { return }
            let dragWorld = delta.processedLocation
            let worldToLocal = CGAffineTransform(translationX: rect.position.x, y: rect.position.y)
                .rotated(by: rect.rotation)
                .inverted()
            let dragLocal = dragWorld.applying(worldToLocal)
            let oppositeLocal = oppositeWorld.applying(worldToLocal)
            primitive.update { prim in
                prim.updateHandle(kind, to: dragLocal, opposite: oppositeLocal)
            }
        case .ended:
            dragState.end(ownerID: primitive.id, kind: kind)
        }
    }

    private func rectHandleLocal(
        kind: CanvasHandle.Kind,
        halfW: CGFloat,
        halfH: CGFloat
    ) -> CGPoint {
        switch kind {
        case .rectTopLeft:
            return CGPoint(x: -halfW, y: halfH)
        case .rectTopRight:
            return CGPoint(x: halfW, y: halfH)
        case .rectBottomRight:
            return CGPoint(x: halfW, y: -halfH)
        case .rectBottomLeft:
            return CGPoint(x: -halfW, y: -halfH)
        default:
            return .zero
        }
    }

    private func toWorld(_ local: CGPoint, position: CGPoint, rotation: CGFloat) -> CGPoint {
        let rotated = local.applying(CGAffineTransform(rotationAngle: rotation))
        return CGPoint(x: rotated.x + position.x, y: rotated.y + position.y)
    }

}

extension PrimitiveView: CKHitTestable {
    func hitTestPath(in context: RenderContext) -> CGPath {
        let base = primitive.value.makePath()
        guard !base.isEmpty else { return CGMutablePath() }

        var transform = CGAffineTransform(
            translationX: primitive.value.position.x,
            y: primitive.value.position.y
        )
        transform = transform.rotated(by: primitive.value.rotation)
        let transformed = base.copy(using: &transform) ?? base

        let padding = 4.0 / max(context.magnification, 0.001)
        let strokeWidth = max(primitive.value.strokeWidth, 1.0) + padding
        let stroked = transformed.copy(
            strokingWithWidth: strokeWidth,
            lineCap: .round,
            lineJoin: .miter,
            miterLimit: 10
        )

        if primitive.value.filled {
            let merged = CGMutablePath()
            merged.addPath(transformed)
            merged.addPath(stroked)
            return merged
        }

        return stroked
    }
}
