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
    
    @Bindable var canvasManager: CanvasManager
    
    @State private var selectedTool: CanvasTool = CursorTool()
    let defaultTool: CanvasTool = CursorTool()

    // Rebuild trigger: changes whenever the pending log’s contents change
    private var pendingStamp: Int {
        projectManager.syncManager.pendingChanges.map(\.id).hashValue
    }
    
    var body: some View {
        CanvasView(
            viewport: $canvasManager.viewport,
            nodes: $projectManager.activeCanvasNodes,
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
            onModelDidChange: { projectManager.document.scheduleAutosave() }
        )
        .onCanvasChange { context in
            canvasManager.mouseLocation = context.processedMouseLocation ?? .zero
        }
        .overlay(alignment: .leading) {
            SchematicToolbarView(selectedSchematicTool: $selectedTool)
                .padding(16)
        }
        .onAppear {
            projectManager.rebuildActiveCanvasNodes()
            projectManager.schematicGraph.onModelDidChange = {
                projectManager.persistSchematicGraph()
                projectManager.document.scheduleAutosave()
            }
        }
        .onChange(of: projectManager.componentInstances) {
            for instance in projectManager.componentInstances {
                guard let symbolDef = instance.definition?.symbol else { continue }
                projectManager.schematicGraph.syncPins(
                    for: instance.symbolInstance,
                    of: symbolDef,
                    ownerID: instance.id
                )
            }
            projectManager.persistSchematicGraph()
            projectManager.document.scheduleAutosave()
        }
        .onChange(of: projectManager.activeCanvasNodes) {
            syncProjectManagerFromNodes()
        }
        // Rebuild the schematic canvas when pending manual-ECO changes are recorded/updated
        .onChange(of: pendingStamp) { _ in
            if projectManager.selectedEditor == .schematic {
                projectManager.rebuildActiveCanvasNodes()
            }
        }
    }
    
    private func syncProjectManagerFromNodes() {
        // Ensure we only perform this sync logic for the schematic editor
        guard projectManager.selectedEditor == .schematic else { return }

        let currentComponentIDs = Set(projectManager.componentInstances.map(\.id))
        let nodeIDs = Set(projectManager.activeCanvasNodes.compactMap { $0 as? SymbolNode }.map(\.id) )
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
        let newSymbolInstance = SymbolInstance(
            definitionUUID: symbolDefinition.uuid, definition: symbolDefinition,
            position: location,
            cardinalRotation: .east
        )
        
        let newComponentInstance = ComponentInstance(definitionUUID: componentDefinition.uuid, definition: componentDefinition, symbolInstance: newSymbolInstance)
        
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
        
        projectManager.document.scheduleAutosave()
        return true
    }
}
