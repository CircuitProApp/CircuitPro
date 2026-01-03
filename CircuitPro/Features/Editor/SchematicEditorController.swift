import Observation
import SwiftDataPacks  // Add this import
import SwiftUI

@MainActor
@Observable
final class SchematicEditorController: EditorController {

    var selectedTool: CanvasTool = CursorTool()

    private let projectManager: ProjectManager
    private let document: CircuitProjectFileDocument

    let wireEngine: WireEngine
    // Track if initial load has happened
    private var hasPerformedInitialLoad = false
    private var isPerformingInitialLoad = false

    var items: [any CanvasItem] = []

    init(projectManager: ProjectManager) {
        self.projectManager = projectManager
        self.document = projectManager.document
        self.wireEngine = WireEngine(graph: CanvasGraph())

        // When wires change in the engine, persist to document.
        self.wireEngine.onWiresChanged = { [weak self] wires in
            guard let self = self else { return }
            guard !self.isPerformingInitialLoad else { return }
            if Thread.isMainThread {
                self.persistWiresToDocument(wires)
            } else {
                Task { @MainActor in
                    self.persistWiresToDocument(wires)
                }
            }
        }

        Task {
            await self.initialLoad()
        }
    }

    // MARK: - Initial Load (once at startup)

    private func initialLoad() async {
        guard !hasPerformedInitialLoad else { return }
        hasPerformedInitialLoad = true
        isPerformingInitialLoad = true

        let design = projectManager.selectedDesign

        items = buildItems(from: design)

        // Load wires from model into engine (one time)
        wireEngine.build(from: design.wires)

        // Sync pin positions
        for inst in design.componentInstances {
            let symbolDef = inst.symbolInstance.definition ?? inst.definition?.symbol
            guard let symbolDef else { continue }
            wireEngine.syncPins(for: inst.symbolInstance, of: symbolDef, ownerID: inst.id)
        }
        wireEngine.repairPinConnections()

        isPerformingInitialLoad = false

    }

    private func buildItems(from design: CircuitDesign) -> [any CanvasItem] {
        design.componentInstances
    }

    func deleteComponentInstances(ids: Set<UUID>) -> Bool {
        guard !ids.isEmpty else { return false }
        let instances = projectManager.componentInstances.filter { ids.contains($0.id) }
        guard !instances.isEmpty else { return false }

        var vertexIDs: Set<UUID> = []
        for inst in instances {
            let symbolDef = inst.symbolInstance.definition ?? inst.definition?.symbol
            guard let symbolDef else { continue }
            for pin in symbolDef.pins {
                if let vertexID = wireEngine.findVertex(ownedBy: inst.id, pinID: pin.id) {
                    vertexIDs.insert(vertexID)
                }
            }
        }

        if !vertexIDs.isEmpty {
            wireEngine.delete(items: vertexIDs)
        }

        projectManager.componentInstances.removeAll { ids.contains($0.id) }
        items.removeAll { ids.contains($0.id) }
        document.scheduleAutosave()
        return true
    }

    // MARK: - Persistence

    /// Called by WireEngine.onChange - saves wires to document model
    private func persistWiresToDocument(_ newWires: [Wire]? = nil) {
        guard !isPerformingInitialLoad else { return }
        let design = projectManager.selectedDesign
        let resolvedWires = newWires ?? wireEngine.toWires()
        guard resolvedWires != design.wires else { return }
        design.wires = resolvedWires
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
        var fetchDescriptor = FetchDescriptor<ComponentDefinition>(
            predicate: #Predicate { $0.uuid == transferable.componentUUID })
        fetchDescriptor.relationshipKeyPathsForPrefetching = [\.symbol]
        let fullLibraryContext = ModelContext(packManager.mainContainer)

        guard let componentDefinition = (try? fullLibraryContext.fetch(fetchDescriptor))?.first,
            let symbolDefinition = componentDefinition.symbol
        else {
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
        items.append(newComponentInstance)

        // The @Observable chain will automatically handle the rest.
        projectManager.document.scheduleAutosave()
        wireEngine.syncPins(
            for: newSymbolInstance,
            of: symbolDefinition,
            ownerID: newComponentInstance.id
        )
        wireEngine.repairPinConnections()
        return true
    }

}
