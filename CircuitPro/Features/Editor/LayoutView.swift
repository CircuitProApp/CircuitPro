import SwiftUI

struct LayoutView: View {
    @BindableEnvironment(\.projectManager)
    private var projectManager
    
    @State var canvasManager: CanvasManager = CanvasManager()
    
    @State private var selectedTool: CanvasTool = CursorTool()
    let defaultTool: CanvasTool = CursorTool()
    
    var body: some View {
        CanvasView(
            viewport: $canvasManager.viewport,
            // --- MODIFIED ---
            nodes: $projectManager.activeCanvasNodes,
            // ---
            selection: $projectManager.selectedNodeIDs,
            tool: $selectedTool.unwrapping(withDefault: defaultTool),
            environment: canvasManager.environment,
            renderLayers: [
                GridRenderLayer(),
                SheetRenderLayer(),
                ElementsRenderLayer(),
                PreviewRenderLayer(),
                MarqueeRenderLayer(),
                CrosshairsRenderLayer()
            ],
            interactions: [
                KeyCommandInteraction(),
                ToolInteraction(),
                SelectionInteraction(),
                DragInteraction(),
                MarqueeInteraction()
            ],
            inputProcessors: [ GridSnapProcessor() ],
            snapProvider: CircuitProSnapProvider(),
            registeredDraggedTypes: [.transferableComponent],
//            onPasteboardDropped: handleComponentDrop,
//            onModelDidChange: { document.scheduleAutosave() }
        )
        .onCanvasChange { context in
            canvasManager.mouseLocation = context.processedMouseLocation ?? .zero
        }
        // --- ADDED: Rebuild nodes when the view appears ---
        .onAppear {
            projectManager.rebuildActiveCanvasNodes()
        }
    }
}

#Preview {
    LayoutView()
}
