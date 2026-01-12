//import AppKit
//
//struct CircleView: CKView {
//    @CKContext var context
//    let circle: CanvasItemRef<CanvasCircle>
//
//    var r: CGFloat {
//        circle.shape.radius
//    }
//    var body: some CKView {
//        CKCircle(radius: circle.shape.radius)
//        HandleView()
//            .position(x: r, y: 0)
//            .onDragGesture { phase in
//                updateCircleHandle(phase)
//            }
//            .hitTestPriority(10)
//    }
//
//    private func updateCircleHandle(_ phase: CanvasDragPhase) {
//        guard case .changed(let delta) = phase else { return }
//        circle.update { prim in
//            guard case .circle(var circle) = prim else { return }
//            let center = circle.position
//            let world = CGPoint(
//                x: delta.processedLocation.x - center.x,
//                y: delta.processedLocation.y - center.y
//            )
//            circle.shape.radius = max(hypot(world.x, world.y), 1)
//            circle.rotation = atan2(world.y, world.x)
//            prim = .circle(circle)
//        }
//    }
//}
