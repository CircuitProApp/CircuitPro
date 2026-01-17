import AppKit

struct LineView: CKView {
    @CKContext var context
    @CKEnvironment var environment
    let line: CanvasLine
    let isEditable: Bool
    @CKState private var dragBaseline: CanvasLine?

    var showHalo: Bool {
        context.highlightedItemIDs.contains(line.id) ||
            context.selectedItemIDs.contains(line.id)
    }

    var body: some CKView {
        CKGroup {
            CKLine(length: line.length, direction: .horizontal)
                .stroke(strokeColor, width: line.strokeWidth)
                .halo(showHalo ? .white.haloOpacity() : .clear, width: 5.0)

            if isEditable {
                let half = line.length / 2
                HandleView()
                    .position(x: -half, y: 0)
                    .onDragGesture { phase in
                        updateLineHandle(.start, phase: phase)
                    }
                    .hitTestPriority(10)
                HandleView()
                    .position(x: half, y: 0)
                    .onDragGesture { phase in
                        updateLineHandle(.end, phase: phase)
                    }
                    .hitTestPriority(10)
            }
        }
    }

    private var strokeColor: CGColor {
        context.layers.first { $0.id == line.layerId }?.color
            ?? environment.canvasTheme.textColor
    }

    private func updateLineHandle(
        _ kind: HandleKind,
        phase: CanvasDragPhase
    ) {
        switch phase {
        case .began:
            dragBaseline = line
        case .changed(let delta):
            guard let baseline = dragBaseline else { return }
            context.update(AnyCanvasPrimitive.line(line)) { prim in
                guard case .line = prim else { return }
                var updated = baseline
                let dragWorld = delta.processedLocation
                if kind == .start {
                    updated.startPoint = dragWorld
                } else {
                    updated.endPoint = dragWorld
                }
                prim = .line(updated)
            }
        case .ended:
            dragBaseline = nil
        }
    }
}

private enum HandleKind {
    case start
    case end
}
