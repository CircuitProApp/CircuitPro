import SwiftUI

struct ConnectionSandboxView: View {
    @State private var canvasManager = CanvasManager()

    @State private var items: [any CanvasItem] = {
        let a = WireVertex(position: CGPoint(x: 120, y: 120))
        let b = WireVertex(position: CGPoint(x: 420, y: 300))
        let c = WireVertex(position: CGPoint(x: 220, y: 40))
        let d = WireVertex(position: CGPoint(x: 520, y: 140))
        let seg1 = WireSegment(startID: a.id, endID: b.id)
        let seg2 = WireSegment(startID: a.id, endID: c.id)
        let seg3 = WireSegment(startID: b.id, endID: d.id)
        return [a, b, c, d, seg1, seg2, seg3]
    }()

    private let engine = ManhattanWireEngine()

    var body: some View {
        CanvasView(
            viewport: $canvasManager.viewport,
            tool: .constant(nil),
            items: $items,
            selectedIDs: .constant([]),
            environment: canvasManager.environment,
            renderLayers: [
                GridRenderLayer(),
                ConnectionDebugRenderLayer(engine: engine),
                CrosshairsRenderLayer(),
            ],
            interactions: [],
            inputProcessors: [],
            snapProvider: NoOpSnapProvider()
        )
        .onCanvasChange { context in
            canvasManager.mouseLocation = context.processedMouseLocation ?? .zero
        }
        .ignoresSafeArea()
    }
}
