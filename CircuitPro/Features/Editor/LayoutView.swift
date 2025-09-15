import SwiftUI

struct LayoutView: View {
    @BindableEnvironment(\.projectManager)
    private var projectManager
    
    // --- ADDED: We need the document to schedule autosaves ---
    var document: CircuitProjectFileDocument
    
    @State var canvasManager: CanvasManager = CanvasManager()
    
    @State private var selectedTool: CanvasTool = CursorTool()
    let defaultTool: CanvasTool = CursorTool()
    
    @State private var canvasLayers: [CanvasLayer] = []
    
    var body: some View {
        CanvasView(
            viewport: $canvasManager.viewport,
            nodes: $projectManager.activeCanvasNodes,
            selection: $projectManager.selectedNodeIDs,
            tool: $selectedTool.unwrapping(withDefault: defaultTool),
            layers: $canvasLayers,
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
            // --- MODIFIED: Register our new draggable type ---
            registeredDraggedTypes: [.transferablePlacement],
            // --- MODIFIED: Implement the drop handler ---
            onPasteboardDropped: handlePlacementDrop,
            onModelDidChange: { document.scheduleAutosave() }
        )
        .onCanvasChange { context in
            canvasManager.mouseLocation = context.processedMouseLocation ?? .zero
        }
        .overlay(alignment: .leading) {
            LayoutToolbarView(selectedSchematicTool: $selectedTool)
                .padding(16)
        }
        .onAppear {
              // This correctly sets up the view when it first appears.
              projectManager.rebuildActiveCanvasNodes()
              self.canvasLayers = projectManager.activeCanvasLayers
          }
          // --- THIS IS THE CRITICAL FIX FOR SWITCHING DESIGNS ---
          .onChange(of: projectManager.selectedDesign) {
              // When the selected design changes while this view is visible:
              // 1. Tell the manager to rebuild its nodes for the new design.
              projectManager.rebuildActiveCanvasNodes()
              // 2. Sync this view's local layer state with the new design's layers.
              self.canvasLayers = projectManager.activeCanvasLayers
          }
    }
    
    // --- ADDED: The drop handler function ---
    /// Handles dropping an unplaced component from the navigator onto the canvas.
    private func handlePlacementDrop(pasteboard: NSPasteboard, location: CGPoint) -> Bool {
        // 1. Check if the pasteboard contains our specific placement data.
        guard let data = pasteboard.data(forType: .transferablePlacement),
              let transferable = try? JSONDecoder().decode(TransferablePlacement.self, from: data) else {
            // If not, this drop is not for us.
            return false
        }
        
        // 2. Call the project manager to perform the state change.
        //    For now, we default to placing on the front side. Flipping can be a separate action.
        projectManager.placeComponent(
            instanceID: transferable.componentInstanceID,
            at: location,
            on: .front
        )
        
        // 3. Tell the canvas we successfully handled this drop.
        return true
    }
}
