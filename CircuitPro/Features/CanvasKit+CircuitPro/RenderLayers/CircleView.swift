import AppKit

struct CircleView: CKView {
    @CKContext var context
    let circle: CanvasCircle
    let isEditable: Bool
    @CKState private var dragCenter: CGPoint?

    var showHalo: Bool {
        context.highlightedItemIDs.contains(circle.id) ||
            context.selectedItemIDs.contains(circle.id)
    }

    var body: some CKView {
        CKGroup {
            CKCircle(radius: circle.radius)
                .fill(circle.filled ? circle.color?.cgColor ?? .white : .clear)
                .stroke(circle.color?.cgColor ?? .white, width: circle.strokeWidth)
                .halo(showHalo ? .white.haloOpacity() : .clear, width: 5.0)

            if isEditable {
                HandleView()
                    .position(x: circle.radius, y: 0)
                    .onDragGesture { phase in
                        updateCircleHandle(phase)
                    }
                    .hitTestPriority(10)
            }
        }
    }

    private func updateCircleHandle(_ phase: CanvasDragPhase) {
        switch phase {
        case .began:
            dragCenter = circle.position
        case .changed(let delta):
            guard let center = dragCenter else { return }
            context.update(circle.id) { prim in
                guard case .circle(var circle) = prim else { return }
                let world = CGPoint(
                    x: delta.processedLocation.x - center.x,
                    y: delta.processedLocation.y - center.y
                )
                circle.radius = max(hypot(world.x, world.y), 1)
                circle.rotation = atan2(world.y, world.x)
                prim = .circle(circle)
            }
        case .ended:
            dragCenter = nil
        }
    }
}
