//
//  SchematicCanvasView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/29/25.
//

import SwiftUI
import SwiftDataPacks

struct SchematicCanvasView: View {

    @BindableEnvironment(\.projectManager) private var projectManager
    
    // The packManager is now only needed for fetching NEW definitions from the library.
    @PackManager private var packManager
    
    var document: CircuitProjectFileDocument
    @Bindable var canvasManager = CanvasManager()

    @State private var selectedTool: CanvasTool = CursorTool()
    let defaultTool: CanvasTool = CursorTool()
    
    var body: some View {
        CanvasView(
            viewport: $canvasManager.viewport,
            nodes: $projectManager.canvasNodes,
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
            // The call is now simpler, with no packManager needed.
            projectManager.rebuildCanvasNodes()
            
            projectManager.schematicGraph.onModelDidChange = {
                projectManager.persistSchematicGraph()
                document.scheduleAutosave()
            }
        }
        .onChange(of: projectManager.componentInstances) {
            // --- CORRECTED ---
            // Move existing pin vertices to their new absolute positions; do NOT rebuild.
            for instance in projectManager.componentInstances {
                // Safely unwrap the definition from the instance itself.
                guard let symbolDef = instance.definition?.symbol else { continue }
                
                projectManager.schematicGraph.syncPins(
                    for: instance.symbolInstance,
                    of: symbolDef,
                    ownerID: instance.id
                )
            }
            // Persist if you want autosave on drags:
            projectManager.persistSchematicGraph()
            document.scheduleAutosave()
        }
        .onChange(of: projectManager.canvasNodes) {
            syncProjectManagerFromNodes()
        }
    }
    
    private func syncProjectManagerFromNodes() {
        // --- CORRECTED ---
        // We no longer need the packManager or the old designComponents().
        // We work directly with the source of truth.
        let currentComponentIDs = Set(projectManager.componentInstances.map(\.id))
        let nodeIDs = Set(projectManager.canvasNodes.map(\.id))
        let missingComponentIDs = currentComponentIDs.subtracting(nodeIDs)

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
         
         // The logic for fetching a definition from the library remains the same.
         // This is the correct and only place the packManager is now needed in this view.
         var fetchDescriptor = FetchDescriptor<ComponentDefinition>(predicate: #Predicate { $0.uuid == transferable.componentUUID })
         fetchDescriptor.relationshipKeyPathsForPrefetching = [\.symbol]
         let fullLibraryContext = ModelContext(packManager.mainContainer)
         
         guard let componentDefinition = (try? fullLibraryContext.fetch(fetchDescriptor))?.first,
               let symbolDefinition = componentDefinition.symbol else {
             return false
         }
         
         // Logic for creating the new instance.
         let instances = projectManager.componentInstances
         let nextRefIndex = (instances.filter { $0.componentUUID == componentDefinition.uuid }.map(\.referenceDesignatorIndex).max() ?? 0) + 1
         
         let newSymbolInstance = SymbolInstance(
             symbolUUID: symbolDefinition.uuid,
             position: location,
             cardinalRotation: .east
         )
         
         // --- IMPORTANT ---
         // The new ComponentInstance does NOT have its `definition` property set yet.
         // This is a small gap in our logic we need to address.
         var newComponentInstance = ComponentInstance(
             componentUUID: componentDefinition.uuid,
             symbolInstance: newSymbolInstance,
             reference: nextRefIndex
         )
         
         // --- HYDRATE THE NEW INSTANCE MANUALLY ---
         // After creating a new instance, we immediately hydrate it with the
         // definition we just fetched.
         newComponentInstance.definition = componentDefinition
         
         // Now, add the fully hydrated instance to the project.
         projectManager.selectedDesign?.componentInstances.append(newComponentInstance)
         
         // The rest of the logic is the same.
         projectManager.schematicGraph.syncPins(
             for: newSymbolInstance,
             of: symbolDefinition,
             ownerID: newComponentInstance.id
         )
         
         document.scheduleAutosave()
         
         return true
     }
}
