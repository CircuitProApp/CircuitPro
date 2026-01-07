import SwiftUI

struct ConnectionSandboxView: View {
    @State private var canvasManager = CanvasManager()

    @State private var manhattanItems: [any CanvasItem] = {
        let a = WireVertex(position: CGPoint(x: 140, y: 140))
        let b = WireVertex(position: CGPoint(x: 420, y: 320))
        let c = WireVertex(position: CGPoint(x: 420, y: 80))
        let corner = WireVertex(position: CGPoint(x: 420, y: 140))
        let d = WireVertex(position: CGPoint(x: 460, y: 140))
        let e = WireVertex(position: CGPoint(x: 460, y: 320))
        let seg1 = WireSegment(startID: a.id, endID: corner.id)
        let seg2 = WireSegment(startID: corner.id, endID: b.id)
        let seg3 = WireSegment(startID: a.id, endID: corner.id)
        let seg4 = WireSegment(startID: corner.id, endID: c.id)
        let seg5 = WireSegment(startID: d.id, endID: e.id)
        return [a, b, c, corner, d, e, seg1, seg2, seg3, seg4, seg5]
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
