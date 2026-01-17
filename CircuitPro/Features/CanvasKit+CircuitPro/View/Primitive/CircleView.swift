import AppKit

struct CircleView: CKView {
    @CKContext var context
    @CKEnvironment var environment
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
                .fill(circle.filled ? strokeColor : .clear)
                .stroke(strokeColor, width: circle.strokeWidth)
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

    private var strokeColor: CGColor {
        context.layers.first { $0.id == circle.layerId }?.color
            ?? environment.canvasTheme.textColor
    }

    private func updateCircleHandle(_ phase: CanvasDragPhase) {
        switch phase {
        case .began:
            dragCenter = circle.position
        case .changed(let delta):
            guard let center = dragCenter else { return }
            context.update(AnyCanvasPrimitive.circle(circle)) { prim in
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
