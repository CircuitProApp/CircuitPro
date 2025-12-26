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

    init(projectManager: ProjectManager) {
        self.projectManager = projectManager
        self.document = projectManager.document
        self.wireEngine = WireEngine(graph: graph)
        self.nodeProvider = SchematicNodeProvider(
            projectManager: projectManager,
            wireEngine: self.wireEngine
        )
        self.canvasStore.onDelta = { [weak self] delta in
            self?.handleStoreDelta(delta)
        }
        self.graph.onDelta = { [weak self] delta in
            self?.handleGraphDelta(delta)
        }

        startTrackingModelChanges()

        Task {
            await self.rebuildNodes()
        }
    }

    private func startTrackingModelChanges() {
        withObservationTracking {
            _ = projectManager.selectedDesign
            _ = projectManager.componentInstances
            _ = projectManager.syncManager.pendingChanges

            // NEW: observe nested symbol/footprint text collections (visibility, overrides, instances)
            for comp in projectManager.componentInstances {
                _ = comp.propertyOverrides
                _ = comp.propertyInstances
                _ = comp.referenceDesignatorIndex
                _ = comp.symbolInstance.textOverrides
                _ = comp.symbolInstance.textInstances
                _ = comp.symbolInstance.resolvedItems
                if let fp = comp.footprintInstance {
                    _ = fp.textOverrides
                    _ = fp.textInstances
                    _ = fp.resolvedItems
                }
            }
        } onChange: {
            Task { @MainActor in
                await self.rebuildNodes()
                self.startTrackingModelChanges()
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

    private func handleStoreDelta(_ delta: CanvasStoreDelta) {
        switch delta {
        case .selectionChanged(let selection):
            guard !suppressGraphSelectionSync else { return }
            let graphSelection = Set(selection.compactMap { id -> NodeID? in
                let nodeID = NodeID(id)
                return graph.nodes.contains(nodeID) ? nodeID : nil
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
