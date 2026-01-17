import AppKit

struct RectangleView: CKView {
    @CKContext var context
    @CKEnvironment var environment
    let rectangle: CanvasRectangle
    let isEditable: Bool
    @CKState private var dragBaseline: CanvasRectangle?

    var showHalo: Bool {
        context.highlightedItemIDs.contains(rectangle.id) ||
            context.selectedItemIDs.contains(rectangle.id)
    }

    var body: some CKView {
        CKGroup {
            CKRectangle(size: rectangle.size, cornerRadius: rectangle.cornerRadius)
                .fill(rectangle.filled ? strokeColor : .clear)
                .stroke(strokeColor, width: rectangle.strokeWidth)
                .halo(showHalo ? .white.haloOpacity() : .clear, width: 5.0)

            if isEditable {
                let halfW = rectangle.size.width / 2
                let halfH = rectangle.size.height / 2

                HandleView()
                    .position(x: -halfW, y: halfH)
                    .onDragGesture { phase in
                        updateRectangleHandle(.topLeft, phase: phase)
                    }
                    .hitTestPriority(10)
                HandleView()
                    .position(x: halfW, y: halfH)
                    .onDragGesture { phase in
                        updateRectangleHandle(.topRight, phase: phase)
                    }
                    .hitTestPriority(10)
                HandleView()
                    .position(x: halfW, y: -halfH)
                    .onDragGesture { phase in
                        updateRectangleHandle(.bottomRight, phase: phase)
                    }
                    .hitTestPriority(10)
                HandleView()
                    .position(x: -halfW, y: -halfH)
                    .onDragGesture { phase in
                        updateRectangleHandle(.bottomLeft, phase: phase)
                    }
                    .hitTestPriority(10)
            }
        }
    }

    private var strokeColor: CGColor {
        context.layers.first { $0.id == rectangle.layerId }?.color
            ?? environment.canvasTheme.textColor
    }

    private func updateRectangleHandle(
        _ kind: HandleKind,
        phase: CanvasDragPhase
    ) {
        switch phase {
        case .began:
            dragBaseline = rectangle
        case .changed(let delta):
            guard let baseline = dragBaseline else { return }
            context.update(AnyCanvasPrimitive.rectangle(rectangle)) { prim in
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
        kind: HandleKind,
        halfW: CGFloat,
        halfH: CGFloat
    ) -> CGPoint {
        switch kind {
        case .topLeft:
            return CGPoint(x: -halfW, y: halfH)
        case .topRight:
            return CGPoint(x: halfW, y: halfH)
        case .bottomRight:
            return CGPoint(x: halfW, y: -halfH)
        case .bottomLeft:
            return CGPoint(x: -halfW, y: -halfH)
        }
    }

    private func updatedRectangle(
        from baseline: CanvasRectangle,
        kind: HandleKind,
        dragWorld: CGPoint
    ) -> CanvasRectangle {
        var updated = baseline
        let halfW = baseline.size.width / 2
        let halfH = baseline.size.height / 2
        let oppositeLocal = rectHandleLocal(
            kind: kind.opposite,
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

private enum HandleKind {
    case topLeft
    case topRight
    case bottomRight
    case bottomLeft

    var opposite: HandleKind {
        switch self {
        case .topLeft:
            return .bottomRight
        case .topRight:
            return .bottomLeft
        case .bottomRight:
            return .topLeft
        case .bottomLeft:
            return .topRight
        }
    }
}
