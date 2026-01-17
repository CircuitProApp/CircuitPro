import SwiftUI

struct WireSandboxView: View {
    @State private var canvasManager = CanvasManager()
    @State private var selectedTool: CanvasTool?
    @State private var wireTool: WireTool

    @State private var manhattanItems: [any CanvasItem] = {
        let a = WireVertex(position: CGPoint(x: 140, y: 140))
        let b = WireVertex(position: CGPoint(x: 420, y: 320))
        let c = WireVertex(position: CGPoint(x: 420, y: 80))
        let corner = WireVertex(position: CGPoint(x: 420, y: 140))
        let d = WireVertex(position: CGPoint(x: 460, y: 140))
        let e = WireVertex(position: CGPoint(x: 460, y: 320))
        let seg1 = WireSegment(startID: a.id, endID: corner.id)
        let seg2 = WireSegment(startID: corner.id, endID: b.id)
        let seg3 = WireSegment(startID: corner.id, endID: c.id)
        let seg4 = WireSegment(startID: d.id, endID: e.id)
        return [a, b, c, corner, d, e, seg1, seg2, seg3, seg4]
    }()

    private let manhattanEngine = WireEngine()

    init() {
        _wireTool = State(initialValue: WireTool(engine: manhattanEngine))
    }

    var body: some View {
        CanvasView(
            tool: $selectedTool,
            items: $manhattanItems,
            selectedIDs: .constant([]),
            environment: canvasManager.environment,
            inputProcessors: [
                GridSnapProcessor(),
            ],
            snapProvider: CircuitProSnapProvider()
        ) {
            GridView()
            WireView(engine: manhattanEngine)
            ConnectionDebugRL(engine: manhattanEngine)
            CrosshairsView()
        }
        .viewport($canvasManager.viewport)
        .overlay(alignment: .bottomLeading) {
            VStack {
                Button {
                    if selectedTool?.id == wireTool.id {
                        selectedTool = nil
                    } else {
                        selectedTool = wireTool
                    }
                } label: {
                    Image(CircuitProSymbols.Schematic.wire)
                        .font(.system(size: 16))
                        .frame(width: 22, height: 22)
                        .contentShape(.rect)
                        .foregroundStyle(
                            selectedTool?.id == wireTool.id ? .blue : .secondary
                        )
                }
            }
            .padding(8)
            .buttonStyle(.plain)
            .glassEffect(in: .capsule)
            .padding(12)
        }
        .ignoresSafeArea()
    }
}
