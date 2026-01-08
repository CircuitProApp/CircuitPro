import SwiftUI

struct BezierSandboxView: View {
    @State private var canvasManager = CanvasManager()

    @State private var bezierItems: [any CanvasItem] = {
        let nodeAID = UUID()
        let nodeBID = UUID()
        let socketAID = UUID()
        let socketBID = UUID()
        let socketCID = UUID()
        let socketDID = UUID()

        let nodeAPosition = CGPoint(x: 200, y: 200)
        let nodeBPosition = CGPoint(x: 460, y: 260)

        let socketAOffset = CGPoint(x: -60, y: 0)
        let socketBOffset = CGPoint(x: 60, y: 0)
        let socketCOffset = CGPoint(x: -70, y: -20)
        let socketDOffset = CGPoint(x: -70, y: 20)

        let nodeA = SandboxNode(
            id: nodeAID,
            position: nodeAPosition,
            size: CGSize(width: 120, height: 80),
            socketOffsets: [
                socketAID: socketAOffset,
                socketBID: socketBOffset,
            ]
        )
        let nodeB = SandboxNode(
            id: nodeBID,
            position: nodeBPosition,
            size: CGSize(width: 120, height: 80),
            socketOffsets: [
                socketCID: socketCOffset,
                socketDID: socketDOffset,
            ]
        )

        let socketA = Socket(
            id: socketAID,
            position: CGPoint(x: nodeAPosition.x + socketAOffset.x, y: nodeAPosition.y + socketAOffset.y),
            ownerID: nodeAID
        )
        let socketB = Socket(
            id: socketBID,
            position: CGPoint(x: nodeAPosition.x + socketBOffset.x, y: nodeAPosition.y + socketBOffset.y),
            ownerID: nodeAID
        )
        let socketC = Socket(
            id: socketCID,
            position: CGPoint(x: nodeBPosition.x + socketCOffset.x, y: nodeBPosition.y + socketCOffset.y),
            ownerID: nodeBID
        )
        let socketD = Socket(
            id: socketDID,
            position: CGPoint(x: nodeBPosition.x + socketDOffset.x, y: nodeBPosition.y + socketDOffset.y),
            ownerID: nodeBID
        )

        let linkAB = BezierLink(startID: socketBID, endID: socketCID)
        let linkCD = BezierLink(startID: socketAID, endID: socketDID)

        return [nodeA, nodeB, socketA, socketB, socketC, socketD, linkAB, linkCD]
    }()

    private let bezierEngine = BezierAdjacencyEngine()

    var body: some View {
        CanvasView(
            viewport: $canvasManager.viewport,
            tool: .constant(nil),
            items: $bezierItems,
            selectedIDs: .constant([]),
            connectionEngine: bezierEngine,
            environment: canvasManager.environment,
            renderLayers: [
                GridRenderLayer(),
                NodeDebugRenderLayer(),
                BezierConnectionDebugRenderLayer(),
                CrosshairsRenderLayer(),
            ],
            interactions: [
                NodeDragInteraction(),
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
