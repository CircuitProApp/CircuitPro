import SwiftUI
import SwiftData

struct SchematicView: View {

    // Injected
    var document: CircuitProjectDocument
    // This can be a @StateObject or passed in.
    @State var canvasManager = CanvasManager()

    @Environment(\.projectManager)
    private var projectManager

    @State private var nodes:  [BaseNode] = []
    @State private var selectedNodeIDs: Set<UUID> = []
    @State private var selectedTool: CanvasTool = CursorTool()
    @State private var defaultTool: CanvasTool = CursorTool()

    var body: some View {
        // We need a bindable version of the manager to pass its selection down.
        // This is the single source of truth for the selection's IDs.
        @Bindable var bindableProjectManager = projectManager
        
        // This no longer needs to be bindable if magnification is the only property used.
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
            inputProcessors: [
                GridSnapProcessor()
            ],
            snapProvider: CircuitProSnapProvider(),
            registeredDraggedTypes: [.transferableComponent],
            onPasteboardDropped: handleComponentDrop
        )
        .overlay(alignment: .leading) {
            SchematicToolbarView(selectedSchematicTool: $selectedTool)
                .padding(16)
        }
    }
    
    /// Handles the drop of a transferable component onto the canvas.
    /// - Returns: `true` if the drop was successfully handled, `false` otherwise.
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
