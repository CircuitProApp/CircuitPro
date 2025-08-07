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
    @State private var connectionTool = ConnectionTool() // The tool instance for our view
    
    // A direct reference to the graph node for easy access
    @State private var schematicGraphNode: SchematicGraphNode?

    var body: some View {
        @Bindable var bindableProjectManager = projectManager
        @Bindable var canvasManager = self.canvasManager

        // --- CONFIGURATION ---
        // Configure our application-specific interaction handler with the models it needs.
        let toolInteraction = ToolInteraction(
            projectManager: self.projectManager,
            document: self.document
        )

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
                toolInteraction, // Our custom handler
                SelectionInteraction(),
                DragInteraction(),
                MarqueeInteraction()
            ],
            inputProcessors: [ GridSnapProcessor() ],
            snapProvider: CircuitProSnapProvider(),
            registeredDraggedTypes: [.transferableComponent],
            onPasteboardDropped: handleComponentDrop
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
        // 1. Create the single SchematicGraphNode for our wiring.
        let graphNode = SchematicGraphNode(graph: projectManager.schematicGraph)
        // Tell it to create its initial WireNode/VertexNode children.
        graphNode.syncChildNodesFromModel()
        // Keep a reference to it for later.
        self.schematicGraphNode = graphNode

        // 2. Create a SymbolNode for each component instance in the project.
        let symbolNodes: [SymbolNode] = projectManager.designComponents.compactMap { designComp in
            guard let symbolDefinition = designComp.definition.symbol else { return nil }
            
            // This is the same resolving logic from your handleComponentDrop function.
            let resolvedProperties = PropertyResolver.resolve(from: designComp.definition, and: designComp.instance)
            let resolvedTexts = TextResolver.resolve(
                from: symbolDefinition,
                and: designComp.instance.symbolInstance,
                componentName: designComp.definition.name,
                reference: designComp.referenceDesignator,
                properties: resolvedProperties
            )

            return SymbolNode(
                instance: designComp.instance.symbolInstance,
                symbol: symbolDefinition,
                resolvedTexts: resolvedTexts
            )
        }
        
        // 3. Combine all nodes into a single array for the canvas.
        self.nodes = symbolNodes + [graphNode]
    }
    
    // handleComponentDrop function remains the same...
    private func handleComponentDrop(pasteboard: NSPasteboard, location: CGPoint) -> Bool {
        // ...
        // Your existing logic here is correct.
        // It correctly mutates the projectManager data model AND the local `nodes` state array.
        // This pattern should be followed for all other actions (e.g., delete).
        // ...
        return true
    }
}
