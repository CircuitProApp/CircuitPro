import SwiftUI

struct LayoutView: View {
    @BindableEnvironment(\.projectManager)
    private var projectManager
    
    var document: CircuitProjectFileDocument
    
    @Bindable var canvasManager: CanvasManager
    
    // --- REMOVED: Local state for the selected tool. ---
    // @State private var selectedTool: CanvasTool = CursorTool()
    let defaultTool: CanvasTool = CursorTool()
    
    // --- REMOVED: Local state for canvas layers. ---
    // @State private var canvasLayers: [CanvasLayer] = []
    
    var body: some View {
        CanvasView(
            viewport: $canvasManager.viewport,
            nodes: $projectManager.activeCanvasNodes,
            selection: $projectManager.selectedNodeIDs,
            // --- MODIFIED: Bind the tool directly to the project manager. ---
            tool: $projectManager.selectedTool.unwrapping(withDefault: defaultTool),
            // --- MODIFIED: Bind layers directly to the project manager. ---
            layers: $projectManager.activeCanvasLayers,
            activeLayerId: $projectManager.activeLayerId,
            environment: canvasManager.environment,
            renderLayers: [
                GridRenderLayer(),
                SheetRenderLayer(),
                ElementsRenderLayer(),
                PreviewRenderLayer(),
                HandlesRenderLayer(),
                MarqueeRenderLayer(),
                CrosshairsRenderLayer()
            ],
            interactions: [
                KeyCommandInteraction(),
                HandleInteraction(),
                ToolInteraction(),
                SelectionInteraction(),
                DragInteraction(),
                MarqueeInteraction()
            ],
            inputProcessors: [ GridSnapProcessor() ],
            snapProvider: CircuitProSnapProvider(),
            registeredDraggedTypes: [.transferablePlacement],
            onPasteboardDropped: handlePlacementDrop,
            onModelDidChange: { document.scheduleAutosave() }
        )
        .onCanvasChange { context in
            canvasManager.mouseLocation = context.processedMouseLocation ?? .zero
        }
        .overlay(alignment: .leading) {
            // --- MODIFIED: The toolbar now binds directly to the project manager's tool. ---
            LayoutToolbarView(selectedSchematicTool: $projectManager.selectedTool)
                .padding(16)
  
            
        }
        .onAppear {
              // This call now rebuilds both nodes AND layers inside the project manager.
              projectManager.rebuildActiveCanvasNodes()
          }
          .onChange(of: projectManager.selectedDesign) {
              // This triggers a rebuild for the new design.
              projectManager.rebuildActiveCanvasNodes()
          }
        // --- REMOVED: The onChange for the local selectedTool is no longer needed. ---
    }
    
    private func handlePlacementDrop(pasteboard: NSPasteboard, location: CGPoint) -> Bool {
        guard let data = pasteboard.data(forType: .transferablePlacement),
              let transferable = try? JSONDecoder().decode(TransferablePlacement.self, from: data) else {
            return false
        }
        
        projectManager.placeComponent(
            instanceID: transferable.componentInstanceID,
            at: location,
            on: .front
        )
        
        return true
    }
}
