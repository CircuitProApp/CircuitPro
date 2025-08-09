import SwiftUI
import SwiftData

struct SchematicView: View {

    // Injected
    var document: CircuitProjectDocument
    @State var canvasManager = CanvasManager()

    @Environment(\.projectManager)
    private var projectManager

    // --- STATE MANAGEMENT ---
    @State private var nodes: [BaseNode] = []
    @State private var selectedNodeIDs: Set<UUID> = []
    
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
            selection: $selectedNodeIDs,
            tool: $selectedTool.unwrapping(withDefault: defaultTool),
            environment: canvasManager.environment,
            renderLayers: [
                GridRenderLayer(),
                ElementsRenderLayer(),
                PreviewRenderLayer(),
                MarqueeRenderLayer(),
                CrosshairsRenderLayer()
            ],
            interactions: [
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
    }
    
    /// Builds the initial scene graph from the ProjectManager's data models.
    /// This method now correctly synchronizes component pins with the SchematicGraph.
    private func setupScene() {
        // Prevent re-running if the view updates.
        guard self.nodes.isEmpty else { return }

        // --- CRITICAL STEP 1: Initialize Graph Model State FIRST ---
        // Before creating any scene nodes, we must tell the graph about every pin from every component instance.
        // This populates the graph model with all the fixed, pin-owned vertices.
        for designComp in projectManager.designComponents {
            guard let symbolDefinition = designComp.definition.symbol else { continue }
            projectManager.schematicGraph.syncPins(for: designComp.instance.symbolInstance, of: symbolDefinition)
        }
        
        // --- STEP 2: Create the Visual Scene Nodes ---
        // Create SymbolNodes for each component instance.
        let symbolNodes: [SymbolNode] = projectManager.designComponents.compactMap { designComp in
            guard let symbolDefinition = designComp.definition.symbol else { return nil }
            let resolvedProperties = PropertyResolver.resolve(from: designComp.definition, and: designComp.instance)
            let resolvedTexts = TextResolver.resolve(from: symbolDefinition, and: designComp.instance.symbolInstance, componentName: designComp.definition.name, reference: designComp.referenceDesignator, properties: resolvedProperties)
            return SymbolNode(instance: designComp.instance.symbolInstance, symbol: symbolDefinition, resolvedTexts: resolvedTexts)
        }
        
        // Create the single SchematicGraphNode which acts as a container for wires and vertices.
        let graphNode = SchematicGraphNode(graph: projectManager.schematicGraph)

        // --- CRITICAL STEP 3: Sync Graph Visuals LAST ---
        // Now that the graph model is fully populated, tell the graph *node* to create
        // its visual children (`VertexNode` and `WireNode`) to match the model.
        graphNode.syncChildNodesFromModel()

        // Atomically set the nodes array for the canvas.
        self.nodes = symbolNodes + [graphNode]
    }
    
    /// Handles dropping a new component onto the canvas from a library.
    private func handleComponentDrop(pasteboard: NSPasteboard, location: CGPoint) -> Bool {
        // 1. Decode the transferable data from the pasteboard.
        guard let data = pasteboard.data(forType: .transferableComponent),
              let transferable = try? JSONDecoder().decode(TransferableComponent.self, from: data) else {
            return false
        }
        
        // 2. Fetch the corresponding Component definition using its UUID.
        let fetchDescriptor = FetchDescriptor<Component>(predicate: #Predicate { $0.uuid == transferable.componentUUID })
        guard let componentDefinition = (try? projectManager.modelContext.fetch(fetchDescriptor))?.first,
              let symbolDefinition = componentDefinition.symbol else {
            return false
        }
        
        // 3. Determine the next available reference designator index for this component type.
        let instances = projectManager.componentInstances
        let nextRefIndex = (instances.filter { $0.componentUUID == componentDefinition.uuid }.map(\.referenceDesignatorIndex).max() ?? 0) + 1
        
        // 4. Create the new data models for the document.
        let newSymbolInstance = SymbolInstance(
            symbolUUID: symbolDefinition.uuid,
            position: location, // The location is already snapped by the canvas input pipeline.
            cardinalRotation: .east
        )
        let newComponentInstance = ComponentInstance(
            componentUUID: componentDefinition.uuid,
            propertyInstances: [],
            symbolInstance: newSymbolInstance,
            footprintInstance: nil,
            reference: nextRefIndex
        )
        
        // 5. Resolve text elements for the visual node.
        let designComp = DesignComponent(definition: componentDefinition, instance: newComponentInstance)
        let resolvedProperties = PropertyResolver.resolve(from: designComp.definition, and: designComp.instance)
        let resolvedTexts = TextResolver.resolve(from: symbolDefinition, and: newComponentInstance.symbolInstance, componentName: componentDefinition.name, reference: designComp.referenceDesignator, properties: resolvedProperties)

        // 6. Create the new visual SymbolNode.
        let newNode = SymbolNode(
            instance: newComponentInstance.symbolInstance,
            symbol: symbolDefinition,
            resolvedTexts: resolvedTexts
        )
        
        // --- 7. MUTATE THE DATA MODELS ---
        projectManager.selectedDesign?.componentInstances.append(newComponentInstance)
        
        // --- 8. SYNC THE GRAPH MODEL ---
        projectManager.schematicGraph.syncPins(for: newSymbolInstance, of: symbolDefinition)

        // --- 9. SYNC THE SCENE GRAPH ---
        nodes.append(newNode)
        
        if let graphNode = nodes.first(where: { $0 is SchematicGraphNode }) as? SchematicGraphNode {
            graphNode.syncChildNodesFromModel()
        }
        
        // 10. Notify the document of the change so it can be saved.
        document.updateChangeCount(.changeDone)
        
        return true
    }
    
    /// Deletes all selected elements from the schematic, maintaining data integrity.
    /// This method is essential and should be called from a main menu command (e.g., Edit > Delete).
    private func deleteSelected() {
        guard !selectedNodeIDs.isEmpty else { return }
        
        let symbolsToDelete = selectedNodeIDs.filter { id in nodes.contains { $0.id == id && $0 is SymbolNode } }
        let graphElementsToDelete = selectedNodeIDs.filter { id in nodes.contains { $0.id == id && ($0 is WireNode || $0 is VertexNode) } }

        // Step A: Release pins of deleted symbols from the graph FIRST.
        for instanceID in symbolsToDelete {
            projectManager.schematicGraph.releasePins(for: instanceID)
        }

        // Step B: Mutate the data models.
        projectManager.componentInstances.removeAll { symbolsToDelete.contains($0.symbolInstance.id) }
        projectManager.schematicGraph.delete(items: Set(graphElementsToDelete))

        // Step C: Update the visual scene graph.
        nodes.removeAll { selectedNodeIDs.contains($0.id) }
        
        if let graphNode = nodes.first(where: { $0 is SchematicGraphNode }) as? SchematicGraphNode {
            graphNode.syncChildNodesFromModel()
        }
        
        selectedNodeIDs.removeAll()
        document.updateChangeCount(.changeDone)
    }
}
