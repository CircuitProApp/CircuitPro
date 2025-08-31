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
            projectManager.rebuildCanvasNodes()
            
            projectManager.schematicGraph.onModelDidChange = {
                projectManager.persistSchematicGraph()
                document.scheduleAutosave()
            }
        }
        .onChange(of: projectManager.componentInstances) {
            for instance in projectManager.componentInstances {
                // Safely unwrap the definition from the instance itself.
                guard let symbolDef = instance.definition?.symbol else { continue }
                
                projectManager.schematicGraph.syncPins(
                    for: instance.symbolInstance,
                    of: symbolDef,
                    ownerID: instance.id
                )
            }
            projectManager.persistSchematicGraph()
            document.scheduleAutosave()
        }
        .onChange(of: projectManager.canvasNodes) {
            syncProjectManagerFromNodes()
        }
    }
    
    private func syncProjectManagerFromNodes() {
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
              let transferable = try? JSONDecoder().decode(TransferableComponent.self, from: data),
              projectManager.selectedDesign != nil else {
            return false
        }
        
        var fetchDescriptor = FetchDescriptor<ComponentDefinition>(predicate: #Predicate { $0.uuid == transferable.componentUUID })
        fetchDescriptor.relationshipKeyPathsForPrefetching = [\.symbol]
        let fullLibraryContext = ModelContext(packManager.mainContainer)
        
        guard let componentDefinition = (try? fullLibraryContext.fetch(fetchDescriptor))?.first,
              let symbolDefinition = componentDefinition.symbol else {
            return false
        }
        
        let instances = projectManager.componentInstances
        let nextRefIndex = (
            instances
                .filter { $0.definitionUUID == componentDefinition.uuid }
                .map { $0.referenceDesignatorIndex}
                .max() ?? 0
        ) + 1
        // Make var so we can set definition
        var newSymbolInstance = SymbolInstance(
            definitionUUID: symbolDefinition.uuid, definition: symbolDefinition,
            position: location,
            cardinalRotation: .east
        )
        
        var newComponentInstance = ComponentInstance(definitionUUID: componentDefinition.uuid, definition: componentDefinition, symbolInstance: newSymbolInstance)
        
        // Append to the selected design
        var currentInstances = projectManager.componentInstances
        currentInstances.append(newComponentInstance)
        projectManager.componentInstances = currentInstances
        
        // Update the wire graph immediately so pins exist at the right place
        projectManager.schematicGraph.syncPins(
            for: newSymbolInstance,
            of: symbolDefinition,
            ownerID: newComponentInstance.id
        )
        
        // Put a SymbolNode into canvasNodes right away (no full rebuild needed)
        projectManager.upsertSymbolNode(for: newComponentInstance)
        
        document.scheduleAutosave()
        return true
    }
}
