import SwiftUI
import SwiftData

struct SchematicCanvasView: View {

    // Injected
    var document: CircuitProjectDocument
    @State var canvasManager = CanvasManager()

    @Environment(\.projectManager)
    private var projectManager

    // --- STATE MANAGEMENT ---
    @State private var nodes: [BaseNode] = []
    
    // We hold the tools in state so they can be configured
    @State private var selectedTool: CanvasTool = CursorTool()
    @State private var defaultTool: CanvasTool = CursorTool()
    
    var body: some View {
        @Bindable var bindableProjectManager = projectManager
        @Bindable var canvasManager = self.canvasManager

        CanvasView(
            size: .constant(PaperSize.component.canvasSize()),
            magnification: $canvasManager.magnification,
            nodes: $nodes,
            selection: $bindableProjectManager.selectedComponentIDs,
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
            onModelDidChange: { self.document.updateChangeCount(.changeDone) }
        )
        .overlay(alignment: .leading) {
            SchematicToolbarView(selectedSchematicTool: $selectedTool)
                .padding(16)
        }
        .onAppear(perform: setupScene)
        .onChange(of: nodes) {
            // Sync changes from Canvas -> ProjectManager
            syncProjectManagerFromNodes()
        }
        .onChange(of: projectManager.designComponents) {
            // Sync changes from ProjectManager -> Canvas
            syncNodesFromProjectManager()
        }
    }
    
    /// Builds the initial scene graph from the ProjectManager's data models.
    private func setupScene() {
        // --- CRITICAL STEP: Initialize Graph Model State FIRST ---
        for designComp in projectManager.designComponents {
            guard let symbolDefinition = designComp.definition.symbol else { continue }
            projectManager.schematicGraph.syncPins(
                for: designComp.instance.symbolInstance,
                of: symbolDefinition,
                ownerID: designComp.id
            )
        }
        
        // Now, build the visual scene from the project manager's state.
        syncNodesFromProjectManager()
    }

    /// Rebuilds the entire scene graph from the `ProjectManager`'s data.
    /// This is the source of truth.
    private func syncNodesFromProjectManager() {
        // First, ensure the graph model is aware of all pins from the source of truth.
        // This is crucial for both initial setup and for when new components are added.
        for designComp in projectManager.designComponents {
            guard let symbolDefinition = designComp.definition.symbol else { continue }
            // Pass the ComponentInstance ID as the owner.
            projectManager.schematicGraph.syncPins(
                for: designComp.instance.symbolInstance,
                of: symbolDefinition,
                ownerID: designComp.id
            )
        }
        
        let symbolNodes: [SymbolNode] = projectManager.designComponents.compactMap { designComp in
            guard let symbolDefinition = designComp.definition.symbol else { return nil }
            let resolvedProperties = PropertyResolver.resolve(from: designComp.definition, and: designComp.instance)
            let resolvedTexts = TextResolver.resolve(from: symbolDefinition, and: designComp.instance.symbolInstance, componentName: designComp.definition.name, reference: designComp.referenceDesignator, properties: resolvedProperties)
            return SymbolNode(
                id: designComp.id,
                instance: designComp.instance.symbolInstance,
                symbol: symbolDefinition,
                resolvedTexts: resolvedTexts,
                graph: projectManager.schematicGraph
            )
        }
        
        let graphNode = SchematicGraphNode(graph: projectManager.schematicGraph)
        graphNode.syncChildNodesFromModel()

        // To prevent infinite update loops, only update the state if the node IDs have actually changed.
        let newNodeIDs = Set(symbolNodes.map(\.id) + [graphNode.id])
        let currentNodeIDs = Set(self.nodes.map(\.id))
        
        if newNodeIDs != currentNodeIDs {
            self.nodes = symbolNodes + [graphNode]
        }
    }
    
    /// Compares the canvas `nodes` with the `ProjectManager` and removes any components
    /// from the manager that no longer have a corresponding node on the canvas.
    private func syncProjectManagerFromNodes() {
        let nodeIDs = Set(nodes.map(\.id))
        
        // Find which components in the project manager are missing from the canvas node list.
        let missingComponents = projectManager.designComponents.filter { !nodeIDs.contains($0.id) }
        
        if !missingComponents.isEmpty {
            // Before deleting the component models, tell the graph to release their pins.
            for component in missingComponents {
                // Release pins using the ComponentInstance ID.
                projectManager.schematicGraph.releasePins(for: component.id)
            }
            
            let idsToRemove = Set(missingComponents.map(\.id))
            projectManager.selectedDesign?.componentInstances.removeAll { idsToRemove.contains($0.id) }
            document.updateChangeCount(.changeDone)
        }
    }
    
    /// Handles dropping a new component onto the canvas from a library.
    private func handleComponentDrop(pasteboard: NSPasteboard, location: CGPoint) -> Bool {
        guard let data = pasteboard.data(forType: .transferableComponent),
              let transferable = try? JSONDecoder().decode(TransferableComponent.self, from: data) else {
            return false
        }
        
        let fetchDescriptor = FetchDescriptor<Component>(predicate: #Predicate { $0.uuid == transferable.componentUUID })
        guard let componentDefinition = (try? projectManager.modelContext.fetch(fetchDescriptor))?.first,
              let symbolDefinition = componentDefinition.symbol else {
            return false
        }
        
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
        
        // --- MUTATE THE DATA MODEL ---
        // The `.onChange(of: projectManager.designComponents)` modifier will automatically
        // call `syncNodesFromProjectManager` to update the canvas.
        projectManager.selectedDesign?.componentInstances.append(newComponentInstance)
        
        // Sync the graph model for the new component.
        projectManager.schematicGraph.syncPins(
            for: newSymbolInstance,
            of: symbolDefinition,
            ownerID: newComponentInstance.id
        )
        
        document.updateChangeCount(.changeDone)
        
        return true
    }
}

