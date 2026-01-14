import AppKit

struct LineView: CKView {
    @CKContext var context
    @CKEnvironment var environment
    let line: CanvasLine
    let isEditable: Bool

    var showHalo: Bool {
        context.highlightedItemIDs.contains(line.id) ||
            context.selectedItemIDs.contains(line.id)
    }

    var body: some CKView {
        let updateLine = { (update: (inout AnyCanvasPrimitive) -> Void) in
            context.updateItem(line.id, as: AnyCanvasPrimitive.self, update)
        }
        CKGroup {
            CKLine(length: line.length, direction: .horizontal)
                .stroke(line.color?.cgColor ?? .white, width: line.strokeWidth)
                .halo(showHalo ? .white.haloOpacity() : .clear, width: 5.0)

            if isEditable {
                let half = line.length / 2
                HandleView()
                    .position(x: -half, y: 0)
                    .onDragGesture { phase in
                        updateLineHandle(.lineStart, phase: phase, update: updateLine)
                    }
                    .hitTestPriority(10)
                HandleView()
                    .position(x: half, y: 0)
                    .onDragGesture { phase in
                        updateLineHandle(.lineEnd, phase: phase, update: updateLine)
                    }
                    .hitTestPriority(10)
            }
        }
    }

    private func updateLineHandle(
        _ kind: CanvasHandle.Kind,
        phase: CanvasDragPhase,
        update: ((inout AnyCanvasPrimitive) -> Void) -> Void
    ) {
        let dragState = environment.handleDragState
        switch phase {
        case .began:
            let oppositeWorld = (kind == .lineStart) ? line.endPoint : line.startPoint
            dragState.begin(ownerID: line.id, kind: kind, oppositeWorld: oppositeWorld)
        case .changed(let delta):
            guard let oppositeWorld = dragState.oppositeWorld(ownerID: line.id, kind: kind) else { return }
            let dragWorld = delta.processedLocation
            let worldToLocal = CGAffineTransform(
                translationX: line.position.x,
                y: line.position.y
            )
            .rotated(by: line.rotation)
            .inverted()
            let dragLocal = dragWorld.applying(worldToLocal)
            let oppositeLocal = oppositeWorld.applying(worldToLocal)
            update { prim in
                prim.updateHandle(kind, to: dragLocal, opposite: oppositeLocal)
            }
        case .ended:
            dragState.end(ownerID: line.id, kind: kind)
        }
    }
}
