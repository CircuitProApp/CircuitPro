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
            // Pass the state-managed tool instance here
            tool: $selectedTool.unwrapping(withDefault: defaultTool),
            environment: canvasManager.environment,
            renderLayers: [
                GridRenderLayer(),
                ElementsRenderLayer(),
                PreviewRenderLayer(),
                MarqueeRenderLayer(),
                CrosshairsRenderLayer()
            ],
            // Provide the fully configured list of interaction handlers
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
            // The toolbar now updates the same selectedTool instance
            SchematicToolbarView(selectedSchematicTool: $selectedTool)
                .padding(16)
        }
        .onAppear(perform: setupScene) // Perform initial setup
    }
    
    /// Builds the initial scene graph from the ProjectManager's data models.
    private func setupScene() {
        // Prevent re-running if the view updates.
        guard self.nodes.isEmpty else { return }

        // 1. Create the single SchematicGraphNode for our wiring.
        let graphNode = SchematicGraphNode(graph: projectManager.schematicGraph)
        graphNode.syncChildNodesFromModel()

        // 2. Create SymbolNodes for each component instance.
        let symbolNodes: [SymbolNode] = projectManager.designComponents.compactMap {
            // ... your existing correct logic to create SymbolNodes ...
            designComp in
            guard let symbolDefinition = designComp.definition.symbol else { return nil }
            let resolvedProperties = PropertyResolver.resolve(from: designComp.definition, and: designComp.instance)
            let resolvedTexts = TextResolver.resolve(from: symbolDefinition, and: designComp.instance.symbolInstance, componentName: designComp.definition.name, reference: designComp.referenceDesignator, properties: resolvedProperties)
            return SymbolNode(instance: designComp.instance.symbolInstance, symbol: symbolDefinition, resolvedTexts: resolvedTexts)
        }
        
        // 3. Atomically set the nodes array ONCE. This is the initial state.
        self.nodes = symbolNodes + [graphNode]
    }
    
    // handleComponentDrop function remains the same...
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
        // The location has already been processed by the canvas's input processors (e.g., snapped to the grid).
        let newSymbolInstance = SymbolInstance(
            symbolUUID: symbolDefinition.uuid,
            position: location, // Use the snapped location directly.
            cardinalRotation: .east
        )

        let newComponentInstance = ComponentInstance(
            componentUUID: componentDefinition.uuid,
            propertyInstances: [],
            symbolInstance: newSymbolInstance,
            footprintInstance: nil,
            reference: nextRefIndex
        )
        
        // 5. Resolve the text elements needed to construct the visual node.
        let designComp = DesignComponent(definition: componentDefinition, instance: newComponentInstance)
        let resolvedProperties = PropertyResolver.resolve(from: designComp.definition, and: designComp.instance)
        let resolvedTexts = TextResolver.resolve(
            from: symbolDefinition,
            and: newSymbolInstance,
            componentName: componentDefinition.name,
            reference: designComp.referenceDesignator,
            properties: resolvedProperties
        )

        // 6. Create the new SymbolNode for the scene graph.
        let newNode = SymbolNode(
            instance: newComponentInstance.symbolInstance,
            symbol: symbolDefinition,
            resolvedTexts: resolvedTexts
        )
        
        // 7. Atomically update the source-of-truth models.
        projectManager.selectedDesign?.componentInstances.append(newComponentInstance)
        nodes.append(newNode)
        
        // 8. Notify the document of the change so it can be saved.
        document.updateChangeCount(.changeDone)
        
        return true
    }
}
