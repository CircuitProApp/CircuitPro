import AppKit

struct CircleView: CKView {
    @CKContext var context
    let circle: CanvasCircle
    let isEditable: Bool

    var showHalo: Bool {
        context.highlightedItemIDs.contains(circle.id) ||
            context.selectedItemIDs.contains(circle.id)
    }

    var body: some CKView {
        let updateCircle = { (update: (inout AnyCanvasPrimitive) -> Void) in
            context.updateItem(circle.id, as: AnyCanvasPrimitive.self, update)
        }
        CKGroup {
            CKCircle(radius: circle.radius)
                .fill(circle.filled ? circle.color?.cgColor ?? .white : .clear)
                .stroke(circle.color?.cgColor ?? .white, width: circle.strokeWidth)
                .halo(showHalo ? .white.haloOpacity() : .clear, width: 5.0)

            if isEditable {
                HandleView()
                    .position(x: circle.radius, y: 0)
                    .onDragGesture { phase in
                        updateCircleHandle(phase, update: updateCircle)
                    }
                    .hitTestPriority(10)
            }
        }
    }

    private func updateCircleHandle(
        _ phase: CanvasDragPhase,
        update: ((inout AnyCanvasPrimitive) -> Void) -> Void
    ) {
        guard case .changed(let delta) = phase else { return }
        update { prim in
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
}
