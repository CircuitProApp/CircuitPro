import SwiftUI
import Observation
import SwiftDataPacks // Add this import

@MainActor
@Observable
final class SchematicEditorController: EditorController {

    let canvasStore = CanvasStore()

    var nodes: [BaseNode] { canvasStore.nodes }

    var selectedTool: CanvasTool = CursorTool()

    private let projectManager: ProjectManager
    private let document: CircuitProjectFileDocument
    private let nodeProvider: SchematicNodeProvider

    let graph = Graph()
    let wireEngine: WireEngine
    private var suppressGraphSelectionSync = false
    private var graphNodeProxyIDs: Set<NodeID> = []

    init(projectManager: ProjectManager) {
        self.projectManager = projectManager
        self.document = projectManager.document
        self.wireEngine = WireEngine(graph: graph)
        self.nodeProvider = SchematicNodeProvider(
            projectManager: projectManager,
            wireEngine: self.wireEngine
        )
        self.canvasStore.onNodesChanged = { [weak self] nodes in
            self?.syncGraphNodeProxies(from: nodes)
        }
        self.canvasStore.onDelta = { [weak self] delta in
            self?.handleStoreDelta(delta)
        }
        self.graph.onDelta = { [weak self] delta in
            self?.handleGraphDelta(delta)
        }

        startTrackingStructureChanges()
        startTrackingTextChanges()

        Task {
            await self.rebuildNodes()
        }
    }

    private func startTrackingStructureChanges() {
        withObservationTracking {
            _ = projectManager.selectedDesign
            _ = projectManager.componentInstances
            _ = projectManager.selectedDesign.wires
        } onChange: {
            Task { @MainActor in
                await self.rebuildNodes()
                self.startTrackingStructureChanges()
            }
        }
    }

    private func startTrackingTextChanges() {
        withObservationTracking {
            _ = projectManager.syncManager.pendingChanges
            for comp in projectManager.componentInstances {
                _ = comp.propertyOverrides
                _ = comp.propertyInstances
                _ = comp.referenceDesignatorIndex
                _ = comp.symbolInstance.textOverrides
                _ = comp.symbolInstance.textInstances
                _ = comp.symbolInstance.resolvedItems
            }
        } onChange: {
            Task { @MainActor in
                self.refreshSymbolTextNodes()
                self.startTrackingTextChanges()
            }
        }
    }

    private func rebuildNodes() async {
        let design = projectManager.selectedDesign

        // This is where the graph is automatically synced on every rebuild.
        let context = BuildContext(activeLayers: [])
        canvasStore.setNodes(await nodeProvider.buildNodes(from: design, context: context))
        wireEngine.build(from: design.wires)
        for inst in design.componentInstances {
            guard let symbolDef = inst.definition?.symbol else { continue }
            wireEngine.syncPins(for: inst.symbolInstance, of: symbolDef, ownerID: inst.id)
        }
    }

    private func refreshSymbolTextNodes() {
        let design = projectManager.selectedDesign
        var didChange = false

        for inst in design.componentInstances {
            guard let symbolNode = canvasStore.nodes.findNode(with: inst.id) as? SymbolNode else {
                continue
            }

            let renderableTexts = inst.symbolInstance.resolvedItems.map { resolvedModel in
                let displayString = projectManager.generateString(for: resolvedModel, component: inst)
                return RenderableText(model: resolvedModel, text: displayString)
            }

            if AnchoredTextNodeSync.sync(
                parent: symbolNode,
                owner: inst.symbolInstance,
                renderableTexts: renderableTexts
            ) {
                didChange = true
            }
        }

        if didChange {
            canvasStore.setNodes(canvasStore.nodes, emitDelta: false)
        }
    }

    private func handleStoreDelta(_ delta: CanvasStoreDelta) {
        switch delta {
        case .selectionChanged(let selection):
            guard !suppressGraphSelectionSync else { return }
            let graphSelection = Set(selection.compactMap { id -> NodeID? in
                let nodeID = NodeID(id)
                return graph.hasAnyComponent(for: nodeID) ? nodeID : nil
            })
            if graph.selection != graphSelection {
                suppressGraphSelectionSync = true
                graph.selection = graphSelection
                suppressGraphSelectionSync = false
            }
        default:
            break
        }
    }

    private func syncGraphNodeProxies(from nodes: [BaseNode]) {
        let selectableNodes = nodes.flattened().filter { $0.isSelectable }
        let newIDs = Set(selectableNodes.map { NodeID($0.id) })

        let removedIDs = graphNodeProxyIDs.subtracting(newIDs)
        for id in removedIDs {
            graph.removeComponent(GraphNodeComponent.self, for: id)
            if !graph.hasAnyComponent(for: id) {
                graph.removeNode(id)
            }
        }

        for node in selectableNodes {
            let nodeID = NodeID(node.id)
            if !graph.nodes.contains(nodeID) {
                graph.addNode(nodeID)
            }
            let kind: GraphNodeComponent.Kind = (node is TextNode) ? .text : .node
            graph.setComponent(GraphNodeComponent(kind: kind), for: nodeID)
        }

        graphNodeProxyIDs = newIDs
    }

    private func handleGraphDelta(_ delta: UnifiedGraphDelta) {
        switch delta {
        case .selectionChanged(let selection):
            guard !suppressGraphSelectionSync else { return }
            let selectionIDs = Set(selection.map { $0.rawValue })
            if canvasStore.selection != selectionIDs {
                suppressGraphSelectionSync = true
                Task { @MainActor in
                    self.canvasStore.selection = selectionIDs
                    self.suppressGraphSelectionSync = false
                }
            }
        default:
            break
        }
    }

    func findNode(with id: UUID) -> BaseNode? {
        return canvasStore.nodes.findNode(with: id)
    }

    private func persistGraph() {
        let design = projectManager.selectedDesign
        design.wires = wireEngine.toWires()
        document.scheduleAutosave()
    }

    // MARK: - Public Actions

    /// Handles dropping a new component onto the canvas from a library.
    /// This logic was moved from SchematicCanvasView.
    func handleComponentDrop(
        from transferable: TransferableComponent,
        at location: CGPoint,
        packManager: SwiftDataPackManager
    ) -> Bool {
        var fetchDescriptor = FetchDescriptor<ComponentDefinition>(predicate: #Predicate { $0.uuid == transferable.componentUUID })
        fetchDescriptor.relationshipKeyPathsForPrefetching = [\.symbol]
        let fullLibraryContext = ModelContext(packManager.mainContainer)

        guard let componentDefinition = (try? fullLibraryContext.fetch(fetchDescriptor))?.first,
                let symbolDefinition = componentDefinition.symbol else {
              return false
          }

        // 1. THE FIX for SymbolInstance
        // We now correctly pass the `definitionUUID` from the symbol's definition.
        let newSymbolInstance = SymbolInstance(
            definitionUUID: symbolDefinition.uuid,
            definition: symbolDefinition,
            position: location
        )

        // 2. THE FIX for ComponentInstance
        // We now correctly pass the `definitionUUID` from the component's definition
        // and the `symbolInstance` we just created.
        let newComponentInstance = ComponentInstance(
            definitionUUID: componentDefinition.uuid,
            definition: componentDefinition,
            symbolInstance: newSymbolInstance
        )

        // This part is already correct. We just mutate the model.
        projectManager.componentInstances.append(newComponentInstance)

        // The @Observable chain will automatically handle the rest.
        projectManager.document.scheduleAutosave()
        return true
    }
}
