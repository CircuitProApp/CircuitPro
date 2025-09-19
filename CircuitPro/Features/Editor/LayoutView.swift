import SwiftUI

struct LayoutView: View {
    @BindableEnvironment(\.projectManager)
    private var projectManager
    
    @Bindable var canvasManager: CanvasManager
    
    var body: some View {
        CanvasView(
            viewport: $canvasManager.viewport,
            nodes: projectManager.activeCanvasNodes,
            selection: $projectManager.selectedNodeIDs,
            tool: $projectManager.selectedTool.unwrapping(withDefault: CursorTool()),
            layers: $projectManager.layoutController.canvasLayers,
            activeLayerId: $projectManager.layoutController.activeLayerId,
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
            onPasteboardDropped: handlePlacementDrop
        )
        .onCanvasChange { context in
            canvasManager.mouseLocation = context.processedMouseLocation ?? .zero
        }
        .overlay(alignment: .leading) {
            // --- MODIFIED: The toolbar now binds directly to the project manager's tool. ---
            LayoutToolbarView(selectedSchematicTool: $projectManager.selectedTool)
                .padding(16)
  
            
        }
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
