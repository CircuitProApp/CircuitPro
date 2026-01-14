import AppKit

struct RectangleView: CKView {
    @CKContext var context
    let rectangle: CanvasRectangle
    let isEditable: Bool
    @CKState private var dragBaseline: CanvasRectangle?

    var showHalo: Bool {
        context.highlightedItemIDs.contains(rectangle.id) ||
            context.selectedItemIDs.contains(rectangle.id)
    }

    var body: some CKView {
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
                        updateRectangleHandle(.rectTopLeft, phase: phase)
                    }
                    .hitTestPriority(10)
                HandleView()
                    .position(x: halfW, y: halfH)
                    .onDragGesture { phase in
                        updateRectangleHandle(.rectTopRight, phase: phase)
                    }
                    .hitTestPriority(10)
                HandleView()
                    .position(x: halfW, y: -halfH)
                    .onDragGesture { phase in
                        updateRectangleHandle(.rectBottomRight, phase: phase)
                    }
                    .hitTestPriority(10)
                HandleView()
                    .position(x: -halfW, y: -halfH)
                    .onDragGesture { phase in
                        updateRectangleHandle(.rectBottomLeft, phase: phase)
                    }
                    .hitTestPriority(10)
            }
        }
    }

    private func updateRectangleHandle(
        _ kind: CanvasHandle.Kind,
        phase: CanvasDragPhase
    ) {
        switch phase {
        case .began:
            dragBaseline = rectangle
        case .changed(let delta):
            guard let baseline = dragBaseline else { return }
            context.update(rectangle.id) { prim in
                guard case .rectangle = prim else { return }
                prim = .rectangle(
                    updatedRectangle(
                        from: baseline,
                        kind: kind,
                        dragWorld: delta.processedLocation
                    )
                )
            }
        case .ended:
            dragBaseline = nil
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

    private func updatedRectangle(
        from baseline: CanvasRectangle,
        kind: CanvasHandle.Kind,
        dragWorld: CGPoint
    ) -> CanvasRectangle {
        var updated = baseline
        let halfW = baseline.size.width / 2
        let halfH = baseline.size.height / 2
        let oppositeLocal = rectHandleLocal(
            kind: kind.opposite ?? kind,
            halfW: halfW,
            halfH: halfH
        )
        let worldToLocal = CGAffineTransform(
            translationX: baseline.position.x,
            y: baseline.position.y
        )
        .rotated(by: baseline.rotation)
        .inverted()
        let dragLocal = dragWorld.applying(worldToLocal)

        updated.size = CGSize(
            width: max(abs(dragLocal.x - oppositeLocal.x), 1),
            height: max(abs(dragLocal.y - oppositeLocal.y), 1)
        )
        let newCenterLocal = CGPoint(
            x: (dragLocal.x + oppositeLocal.x) * 0.5,
            y: (dragLocal.y + oppositeLocal.y) * 0.5
        )
        let positionOffset = newCenterLocal.applying(CGAffineTransform(rotationAngle: baseline.rotation))
        updated.position = CGPoint(
            x: baseline.position.x + positionOffset.x,
            y: baseline.position.y + positionOffset.y
        )
        return updated
    }
}
