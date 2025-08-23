//
//  SchematicCanvasView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/29/25.
//

import SwiftUI
import SwiftDataPacks

struct SchematicCanvasView: View {

    @Environment(\.projectManager)
    private var projectManager
    
    // We will use this to perform data operations.
    @PackManager private var packManager
    
    var document: CircuitProjectFileDocument
    @State var canvasManager = CanvasManager()

    @State private var selectedTool: CanvasTool = CursorTool()
    let defaultTool: CanvasTool = CursorTool()
    
    var body: some View {
        @Bindable var bindableProjectManager = projectManager
        @Bindable var canvasManager = self.canvasManager

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
            onPasteboardDropped: handleComponentDrop,
            onModelDidChange: { document.scheduleAutosave() }
        )
        .onCanvasChange { context in
            canvasManager.mouseLocation = context.processedMouseLocation ?? .zero
        }
        .overlay(alignment: .leading) {
            SchematicToolbarView(selectedSchematicTool: $selectedTool)
                .padding(16)
        }
        .onAppear {
            projectManager.rebuildCanvasNodes(with: packManager)
            
            projectManager.schematicGraph.onModelDidChange = {
                projectManager.persistSchematicGraph()
                document.scheduleAutosave()
            }
        }
        .onChange(of: projectManager.componentInstances) {
            projectManager.rebuildCanvasNodes(with: packManager)
        }
        .onChange(of: projectManager.canvasNodes) {
            syncProjectManagerFromNodes()
        }
    }
    
    private func syncProjectManagerFromNodes() {
        // We need the packManager here to resolve the component list
        let currentDesignComponents = projectManager.designComponents(using: packManager)
        
        let nodeIDs = Set(projectManager.canvasNodes.map(\.id))
        let missingComponentIDs = Set(currentDesignComponents.map(\.id)).subtracting(nodeIDs)

        if !missingComponentIDs.isEmpty {
            for componentID in missingComponentIDs {
                projectManager.schematicGraph.releasePins(for: componentID)
            }
            projectManager.selectedDesign?.componentInstances.removeAll { missingComponentIDs.contains($0.id) }
        }
    }
    
    /// Handles dropping a new component onto the canvas from a library.
    private func handleComponentDrop(pasteboard: NSPasteboard, location: CGPoint) -> Bool {
         guard let data = pasteboard.data(forType: .transferableComponent),
               let transferable = try? JSONDecoder().decode(TransferableComponent.self, from: data) else {
             return false
         }
         
         // Create a fetch descriptor to find the component definition by its unique ID.
         var fetchDescriptor = FetchDescriptor<Component>(predicate: #Predicate { $0.uuid == transferable.componentUUID })
         
         fetchDescriptor.relationshipKeyPathsForPrefetching = [\.symbol]
         
         let fullLibraryContext = ModelContext(packManager.mainContainer)
         
         // This guard statement will now succeed because the symbol data is already loaded.
         guard let componentDefinition = (try? fullLibraryContext.fetch(fetchDescriptor))?.first,
               let symbolDefinition = componentDefinition.symbol else {
             return false
         }
         
         // The rest of the logic remains the same.
         let instances = projectManager.componentInstances
         let nextRefIndex = (instances.filter { $0.componentUUID == componentDefinition.uuid }.map(\.referenceDesignatorIndex).max() ?? 0) + 1
         
         let newSymbolInstance = SymbolInstance(
             symbolUUID: symbolDefinition.uuid,
             position: location,
             cardinalRotation: .east
         )
         let newComponentInstance = ComponentInstance(
             componentUUID: componentDefinition.uuid,
             propertyInstances: [],
             symbolInstance: newSymbolInstance,
             footprintInstance: nil,
             reference: nextRefIndex
         )
         
         projectManager.selectedDesign?.componentInstances.append(newComponentInstance)
         
         projectManager.schematicGraph.syncPins(
             for: newSymbolInstance,
             of: symbolDefinition,
             ownerID: newComponentInstance.id
         )
         
         document.scheduleAutosave()
         
         return true
     }
}
