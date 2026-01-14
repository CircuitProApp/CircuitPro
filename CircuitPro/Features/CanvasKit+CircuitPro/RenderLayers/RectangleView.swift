import AppKit

struct RectangleView: CKView {
    @CKContext var context
    @CKEnvironment var environment
    let rectangle: CanvasRectangle
    let isEditable: Bool

    var showHalo: Bool {
        context.highlightedItemIDs.contains(rectangle.id) ||
            context.selectedItemIDs.contains(rectangle.id)
    }

    var body: some CKView {
        let updateRectangle = { (update: (inout AnyCanvasPrimitive) -> Void) in
            context.updateItem(rectangle.id, as: AnyCanvasPrimitive.self, update)
        }
        let dragState = environment.handleDragState
        CKGroup {
            CKRectangle(cornerRadius: rectangle.cornerRadius)
                .frame(width: rectangle.size.width, height: rectangle.size.height)
                .fill(rectangle.filled ? rectangle.color?.cgColor ?? .white : .clear)
                .stroke(rectangle.color?.cgColor ?? .white, width: rectangle.strokeWidth)
                .halo(showHalo ? .white.haloOpacity() : .clear, width: 5.0)

            if isEditable {
                let halfW = rectangle.size.width / 2
                let halfH = rectangle.size.height / 2

                HandleView()
                    .position(x: -halfW, y: halfH)
                    .onDragGesture { phase in
                        updateRectangleHandle(.rectTopLeft, phase: phase, update: updateRectangle, dragState: dragState)
                    }
                    .hitTestPriority(10)
                HandleView()
                    .position(x: halfW, y: halfH)
                    .onDragGesture { phase in
                        updateRectangleHandle(.rectTopRight, phase: phase, update: updateRectangle, dragState: dragState)
                    }
                    .hitTestPriority(10)
                HandleView()
                    .position(x: halfW, y: -halfH)
                    .onDragGesture { phase in
                        updateRectangleHandle(.rectBottomRight, phase: phase, update: updateRectangle, dragState: dragState)
                    }
                    .hitTestPriority(10)
                HandleView()
                    .position(x: -halfW, y: -halfH)
                    .onDragGesture { phase in
                        updateRectangleHandle(.rectBottomLeft, phase: phase, update: updateRectangle, dragState: dragState)
                    }
                    .hitTestPriority(10)
            }
        }
    }

    private func updateRectangleHandle(
        _ kind: CanvasHandle.Kind,
        phase: CanvasDragPhase,
        update: ((inout AnyCanvasPrimitive) -> Void) -> Void,
        dragState: CanvasHandleDragState
    ) {
        switch phase {
        case .began:
            let halfW = rectangle.size.width / 2
            let halfH = rectangle.size.height / 2
            let oppositeLocal = rectHandleLocal(
                kind: kind.opposite ?? kind,
                halfW: halfW,
                halfH: halfH
            )
            let oppositeWorld = toWorld(
                oppositeLocal,
                position: rectangle.position,
                rotation: rectangle.rotation
            )
            dragState.begin(ownerID: rectangle.id, kind: kind, oppositeWorld: oppositeWorld)
        case .changed(let delta):
            guard let oppositeWorld = dragState.oppositeWorld(ownerID: rectangle.id, kind: kind) else { return }
            let dragWorld = delta.processedLocation
            let worldToLocal = CGAffineTransform(
                translationX: rectangle.position.x,
                y: rectangle.position.y
            )
            .rotated(by: rectangle.rotation)
            .inverted()
            let dragLocal = dragWorld.applying(worldToLocal)
            let oppositeLocal = oppositeWorld.applying(worldToLocal)
            update { prim in
                prim.updateHandle(kind, to: dragLocal, opposite: oppositeLocal)
            }
        case .ended:
            dragState.end(ownerID: rectangle.id, kind: kind)
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
