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

        let socketA = Socket(id: socketAID, offset: CGPoint(x: -60, y: 0))
        let socketB = Socket(id: socketBID, offset: CGPoint(x: 60, y: 0))
        let socketC = Socket(id: socketCID, offset: CGPoint(x: -70, y: -20))
        let socketD = Socket(id: socketDID, offset: CGPoint(x: -70, y: 20))

        let nodeA = SandboxNode(
            id: nodeAID,
            position: nodeAPosition,
            size: CGSize(width: 120, height: 80),
            sockets: [socketA, socketB]
        )
        let nodeB = SandboxNode(
            id: nodeBID,
            position: nodeBPosition,
            size: CGSize(width: 120, height: 80),
            sockets: [socketC, socketD]
        )

        let linkAB = BezierLink(startID: socketBID, endID: socketCID)
        let linkCD = BezierLink(startID: socketAID, endID: socketDID)

        return [nodeA, nodeB, linkAB, linkCD]
    }()

    private let bezierEngine = BezierAdjacencyEngine()

    var body: some View {
        CanvasView(
            tool: .constant(nil),
            items: $bezierItems,
            selectedIDs: .constant([]),
            environment: canvasManager.environment,
            inputProcessors: [
                GridSnapProcessor(),
            ],
            snapProvider: CircuitProSnapProvider()
        ) {
            GridView()
            NodeDebugRL()
            BezierConnectionDebugRL(engine: bezierEngine)
            CrosshairsView()
        }
        .viewport($canvasManager.viewport)
        .ignoresSafeArea()
    }
}
