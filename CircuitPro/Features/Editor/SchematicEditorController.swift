import Observation
import SwiftDataPacks  // Add this import
import SwiftUI

@MainActor
@Observable
final class SchematicEditorController: EditorController {

    let canvasStore = CanvasStore()

    var selectedTool: CanvasTool = CursorTool()

    private let projectManager: ProjectManager
    private let document: CircuitProjectFileDocument

    let graph = CanvasGraph()
    let wireEngine: WireEngine
    private var suppressGraphSelectionSync = false
    private var isSyncingTextFromModel = false
    private var isApplyingTextChangesToModel = false

    // Track if initial load has happened
    private var hasPerformedInitialLoad = false
    private var isPerformingInitialLoad = false


    var items: [any CanvasItem] {
        let design = projectManager.selectedDesign
        var result: [any CanvasItem] = []

        for inst in design.componentInstances {
            result.append(inst)

            let ownerPosition = inst.symbolInstance.position
            let ownerRotation = inst.symbolInstance.rotation

            for resolvedModel in inst.symbolInstance.resolvedItems {
                let overlaySource: ChangeSource? =
                    projectManager.syncManager.syncMode == .manualECO ? .schematic : nil
                let displayString = projectManager.generateString(
                    for: resolvedModel, component: inst, overlaySource: overlaySource)
                let component = CanvasText(
                    resolvedText: resolvedModel,
                    displayText: displayString,
                    ownerID: inst.id,
                    target: .symbol,
                    ownerPosition: ownerPosition,
                    ownerRotation: ownerRotation,
                    layerId: nil,
                    showsAnchorGuides: true
                )
                result.append(component)
            }

            let symbolDef = inst.symbolInstance.definition ?? inst.definition?.symbol
            guard let symbolDef else { continue }
            for pinDef in symbolDef.pins {
                let component = CanvasPin(
                    pin: pinDef,
                    ownerID: inst.id,
                    ownerPosition: ownerPosition,
                    ownerRotation: ownerRotation,
                    layerId: nil,
                    isSelectable: false
                )
                result.append(component)
            }
        }

        return result
    }

    init(projectManager: ProjectManager) {
        self.projectManager = projectManager
        self.document = projectManager.document
        self.wireEngine = WireEngine(graph: graph)

        // When wires change in the engine, persist to document
        self.wireEngine.onChange = { [weak self] in
            guard let self = self else { return }
            // Don't persist during initial load
            guard !self.isPerformingInitialLoad else { return }
            if Thread.isMainThread {
                self.persistWiresToDocument()
            } else {
                Task { @MainActor in
                    self.persistWiresToDocument()
                }
            }
        }

        self.canvasStore.onDelta = { [weak self] delta in
            self?.handleStoreDelta(delta)
        }
        self.graph.onDelta = { [weak self] delta in
            self?.handleGraphDelta(delta)
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

        canvasStore.invalidate()
    }

    private func handleStoreDelta(_ delta: CanvasStoreDelta) {
        switch delta {
        case .selectionChanged(let selection):
            guard !suppressGraphSelectionSync else { return }
            let graphSelection = Set(
                selection.compactMap { id -> GraphElementID? in
                    let nodeID = NodeID(id)
                    return graph.hasAnyComponent(for: nodeID) ? .node(nodeID) : nil
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
            let graphSelectionIDs = Set(selection.compactMap { $0.nodeID?.rawValue })
            if canvasStore.selection != graphSelectionIDs {
                suppressGraphSelectionSync = true
                Task { @MainActor in
                    self.canvasStore.selection = graphSelectionIDs
                    self.suppressGraphSelectionSync = false
                }
            }
        case .nodeComponentSet(let id, let componentKey):
            if componentKey == ObjectIdentifier(CanvasText.self),
                let component = graph.component(CanvasText.self, for: id),
                !isSyncingTextFromModel
            {
                applyGraphTextChange(component)
            } else if componentKey == ObjectIdentifier(ComponentInstance.self),
                let component = graph.component(ComponentInstance.self, for: id)
            {
                syncOwnedComponents(for: component)
            }
            canvasStore.invalidate()
        case .edgeComponentSet,
            .edgeComponentRemoved,
            .edgeAdded,
            .edgeRemoved,
            .nodeRemoved,
            .nodeAdded,
            .nodeComponentRemoved:
            canvasStore.invalidate()
        default:
            break
        }
    }

    private func applyGraphTextChange(_ component: CanvasText) {
        guard !isApplyingTextChangesToModel else { return }
        guard
            let inst = projectManager.componentInstances.first(where: { $0.id == component.ownerID }
            )
        else { return }

        if let current = inst.symbolInstance.resolvedItems.first(where: {
            $0.id == component.resolvedText.id
        }) {
            let currentPosition = current.relativePosition
            let currentAnchor = current.anchorPosition
            let currentRotation = current.cardinalRotation
            let currentVisibility = current.isVisible
            let nextPosition = component.resolvedText.relativePosition
            let nextAnchor = component.resolvedText.anchorPosition
            let nextRotation = component.resolvedText.cardinalRotation
            let nextVisibility = component.resolvedText.isVisible
            if currentPosition == nextPosition,
                currentAnchor == nextAnchor,
                currentRotation == nextRotation,
                currentVisibility == nextVisibility
            {
                return
            }
        }

        isApplyingTextChangesToModel = true
        inst.apply(component.resolvedText, for: component.target)
        document.scheduleAutosave()
        isApplyingTextChangesToModel = false
    }

    private func syncOwnedComponents(for component: ComponentInstance) {
        let ownerID = component.id
        let ownerPosition = component.symbolInstance.position
        let ownerRotation = component.symbolInstance.rotation

        for (_, pin) in graph.components(CanvasPin.self) where pin.ownerID == ownerID {
            pin.ownerPosition = ownerPosition
            pin.ownerRotation = ownerRotation
        }

        for (_, text) in graph.components(CanvasText.self) where text.ownerID == ownerID {
            text.ownerPosition = ownerPosition
            text.ownerRotation = ownerRotation
        }

        let symbolDef = component.symbolInstance.definition ?? component.definition?.symbol
        if let symbolDef {
            wireEngine.syncPins(for: component.symbolInstance, of: symbolDef, ownerID: ownerID)
        }
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
        document.scheduleAutosave()
        return true
    }

    func textBinding(for id: UUID) -> Binding<CanvasText>? {
        let nodeID = NodeID(id)
        guard let component = graph.component(CanvasText.self, for: nodeID) else { return nil }
        return Binding(
            get: { component },
            set: { newValue in
                self.setTextComponent(newValue, for: nodeID)
            }
        )
    }

    private func setTextComponent(_ component: CanvasText, for id: NodeID) {
        if !graph.nodes.contains(id) {
            graph.addNode(id)
        }
        graph.setComponent(component, for: id)
    }

    // MARK: - Persistence

    /// Called by WireEngine.onChange - saves wires to document model
    private func persistWiresToDocument() {
        let design = projectManager.selectedDesign
        let newWires = wireEngine.toWires()
        guard newWires != design.wires else { return }
        design.wires = newWires
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

        // The @Observable chain will automatically handle the rest.
        projectManager.document.scheduleAutosave()
        wireEngine.syncPins(
            for: newSymbolInstance,
            of: symbolDefinition,
            ownerID: newComponentInstance.id
        )
        wireEngine.repairPinConnections()
        canvasStore.invalidate()
        return true
    }
}
