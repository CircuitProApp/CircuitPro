import SwiftUI

struct ConnectionSandboxView: View {
    @State private var canvasManager = CanvasManager()

    @State private var manhattanItems: [any CanvasItem] = {
        let a = WireVertex(position: CGPoint(x: 140, y: 140))
        let b = WireVertex(position: CGPoint(x: 420, y: 320))
        let c = WireVertex(position: CGPoint(x: 420, y: 80))
        let seg1 = WireSegment(startID: a.id, endID: b.id)
        let seg2 = WireSegment(startID: a.id, endID: c.id)
        return [a, b, c, seg1, seg2]
    }()

    private let manhattanEngine = ManhattanWireEngine()

    var body: some View {
        CanvasView(
            viewport: $canvasManager.viewport,
            tool: .constant(nil),
            items: $manhattanItems,
            selectedIDs: .constant([]),
            connectionEngine: manhattanEngine,
            environment: canvasManager.environment,
            renderLayers: [
                GridRenderLayer(),
                ConnectionDebugRenderLayer(),
                CrosshairsRenderLayer(),
            ],
            interactions: [
                WireEdgeDragInteraction(),
            ],
            inputProcessors: [
                GridSnapProcessor(),
            ],
            snapProvider: CircuitProSnapProvider()
        )
        .onCanvasChange { context in
            canvasManager.mouseLocation = context.processedMouseLocation ?? .zero
        }
        .ignoresSafeArea()
    }
}
