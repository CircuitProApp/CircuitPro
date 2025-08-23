import SwiftUI

struct LayoutView: View {
    @Environment(\.projectManager)
    private var projectManager
    
    @State var canvasManager: CanvasManager = CanvasManager()
    
    @State private var selectedTool: CanvasTool = CursorTool()
    let defaultTool: CanvasTool = CursorTool()
    
    var body: some View {
        @Bindable var bindableProjectManager = projectManager
        CanvasView(
            viewport: $canvasManager.viewport,
            nodes: $bindableProjectManager.canvasNodes,
            selection: $bindableProjectManager.selectedNodeIDs,
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
    }
}

#Preview {
    LayoutView()
}
