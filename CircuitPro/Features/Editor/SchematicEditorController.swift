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

    let schematicGraph: WireGraph

    init(projectManager: ProjectManager) {
        self.projectManager = projectManager
        self.document = projectManager.document
        self.schematicGraph = WireGraph()
        self.nodeProvider = SchematicNodeProvider(
            projectManager: projectManager,
            schematicGraph: self.schematicGraph
        )

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
                _ = comp.symbolInstance.resolvedItems
                if let fp = comp.footprintInstance {
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
    }

    func findNode(with id: UUID) -> BaseNode? {
        return canvasStore.nodes.findNode(with: id)
    }

    private func persistGraph() {
        let design = projectManager.selectedDesign
        design.wires = schematicGraph.toWires()
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
