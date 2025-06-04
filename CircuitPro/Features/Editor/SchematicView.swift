import SwiftUI
import SwiftData

struct SchematicView: View {
    var canvasManager: CanvasManager = CanvasManager()
    
    @State private var canvasElements: [CanvasElement] = []
    @State private var selectedIDs: Set<UUID> = []
    @State private var selectedTool: AnyCanvasTool = .init(CursorTool())
    
    @State private var selectedLayer: LayerKind?
    @State private var layerAssignments: [UUID: LayerKind] = [:]
    var body: some View {
        CanvasView(manager: canvasManager, elements: $canvasElements, selectedIDs: $selectedIDs, selectedTool: $selectedTool, selectedLayer: $selectedLayer, layerAssignments: $layerAssignments)
            .dropDestination(for: TransferableComponent.self) { component, location  in
                print(component.count, location)
                return true
            }
            .overlay(alignment: .leading) {
                SymbolDesignToolbarView()
                    .padding(16)
            }
    }
}

#Preview {
    SchematicView()
}
