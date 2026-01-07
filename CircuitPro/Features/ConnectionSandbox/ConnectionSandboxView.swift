import SwiftUI

struct ConnectionSandboxView: View {
    @State private var canvasManager = CanvasManager()

    @State private var items: [any CanvasItem] = {
        let nodeA = AnyCanvasPrimitive.rectangle(CanvasRectangle(
            id: UUID(),
            shape: RectanglePrimitive(size: CGSize(width: 160, height: 80), cornerRadius: 10),
            position: CGPoint(x: 200, y: 200),
            rotation: 0,
            strokeWidth: 2,
            filled: true,
            color: SDColor(color: .gray),
            layerId: nil
        ))
        let nodeB = AnyCanvasPrimitive.rectangle(CanvasRectangle(
            id: UUID(),
            shape: RectanglePrimitive(size: CGSize(width: 180, height: 90), cornerRadius: 10),
            position: CGPoint(x: 520, y: 320),
            rotation: 0,
            strokeWidth: 2,
            filled: true,
            color: SDColor(color: .gray),
            layerId: nil
        ))
        let nodeC = AnyCanvasPrimitive.rectangle(CanvasRectangle(
            id: UUID(),
            shape: RectanglePrimitive(size: CGSize(width: 180, height: 90), cornerRadius: 10),
            position: CGPoint(x: 520, y: 120),
            rotation: 0,
            strokeWidth: 2,
            filled: true,
            color: SDColor(color: .gray),
            layerId: nil
        ))

        var socketA = Socket(position: CGPoint(x: 280, y: 200), ownerID: nodeA.id)
        var socketB = Socket(position: CGPoint(x: 430, y: 320), ownerID: nodeB.id)
        var socketC = Socket(position: CGPoint(x: 430, y: 120), ownerID: nodeC.id)
        socketA.connectedIDs = [socketB.id, socketC.id]
        socketB.connectedIDs = [socketA.id]
        socketC.connectedIDs = [socketA.id]

        return [nodeA, nodeB, nodeC, socketA, socketB, socketC]
    }()

    private let engine = BezierAdjacencyEngine()

    var body: some View {
        CanvasView(
            viewport: $canvasManager.viewport,
            tool: .constant(nil),
            items: $items,
            selectedIDs: .constant([]),
            environment: canvasManager.environment,
            renderLayers: [
                GridRenderLayer(),
                ElementsRenderLayer(),
                BezierConnectionDebugRenderLayer(engine: engine),
                CrosshairsRenderLayer(),
            ],
            interactions: [
                NodeDragInteraction(),
            ],
            inputProcessors: [],
            snapProvider: NoOpSnapProvider()
        )
        .onCanvasChange { context in
            canvasManager.mouseLocation = context.processedMouseLocation ?? .zero
        }
        .ignoresSafeArea()
    }
}
