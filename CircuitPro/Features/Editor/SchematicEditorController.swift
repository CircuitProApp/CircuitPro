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

        startTrackingStructureChanges()
        startTrackingTextChanges()

        Task {
            await self.initialLoad()
        }
    }

    private func startTrackingStructureChanges() {
        withObservationTracking {
            _ = projectManager.selectedDesign
            _ = projectManager.componentInstances
        } onChange: {
            Task { @MainActor in
                await self.refreshSymbols()
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
                _ = comp.symbolInstance.position
                _ = comp.symbolInstance.cardinalRotation
            }
        } onChange: {
            Task { @MainActor in
                self.refreshSymbolTextNodes()
                self.refreshSymbolPinComponents()
                self.canvasStore.invalidate()
                self.startTrackingTextChanges()
            }
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

        // Load graph components for text and pins (needed for selection/editing)
        refreshSymbolComponents()
        refreshSymbolTextNodes()
        refreshSymbolPinComponents()
        canvasStore.invalidate()
    }

    // MARK: - Symbol Refresh (when structure changes)

    private func refreshSymbols() async {
        // Update graph components for text and pins
        refreshSymbolComponents()
        refreshSymbolTextNodes()
        refreshSymbolPinComponents()

        // Sync pins when symbols change (component added/moved)
        let wasLoading = isPerformingInitialLoad
        isPerformingInitialLoad = true

        let design = projectManager.selectedDesign
        for inst in design.componentInstances {
            let symbolDef = inst.symbolInstance.definition ?? inst.definition?.symbol
            guard let symbolDef else { continue }
            wireEngine.syncPins(for: inst.symbolInstance, of: symbolDef, ownerID: inst.id)
        }

        isPerformingInitialLoad = wasLoading
        canvasStore.invalidate()
    }

    private func refreshSymbolComponents() {
        let design = projectManager.selectedDesign
        var updatedIDs = Set<NodeID>()

        for inst in design.componentInstances {
            let nodeID = NodeID(inst.id)
            if !graph.nodes.contains(nodeID) {
                graph.addNode(nodeID)
            }
            graph.setComponent(inst, for: nodeID)
            updatedIDs.insert(nodeID)
        }

        let existingIDs = Set(graph.nodeIDs(with: ComponentInstance.self))
        for id in existingIDs.subtracting(updatedIDs) {
            graph.removeComponent(ComponentInstance.self, for: id)
            if !graph.hasAnyComponent(for: id) {
                graph.removeNode(id)
            }
        }
    }

    // MARK: - Graph Component Refresh (for text and pin selection/editing)

    func refreshSymbolTextNodes() {
        let design = projectManager.selectedDesign
        isSyncingTextFromModel = true
        var updatedIDs = Set<NodeID>()

        for inst in design.componentInstances {
            let ownerPosition = inst.symbolInstance.position
            let ownerRotation = inst.symbolInstance.rotation

            for resolvedModel in inst.symbolInstance.resolvedItems {
                let overlaySource: ChangeSource? =
                    projectManager.syncManager.syncMode == .manualECO ? .schematic : nil
                let displayString = projectManager.generateString(
                    for: resolvedModel, component: inst, overlaySource: overlaySource)
                let textID = GraphTextID.makeID(
                    for: resolvedModel.source, ownerID: inst.id, fallback: resolvedModel.id)
                let nodeID = NodeID(textID)

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

                if !graph.nodes.contains(nodeID) {
                    graph.addNode(nodeID)
                }
                graph.setComponent(component, for: nodeID)
                updatedIDs.insert(nodeID)
            }
        }

        let existingIDs = Set(graph.nodeIDs(with: CanvasText.self))
        for id in existingIDs.subtracting(updatedIDs) {
            graph.removeComponent(CanvasText.self, for: id)
            if !graph.hasAnyComponent(for: id) {
                graph.removeNode(id)
            }
        }

        isSyncingTextFromModel = false
        canvasStore.invalidate()
    }

    private func refreshSymbolPinComponents() {
        let design = projectManager.selectedDesign
        var updatedIDs = Set<NodeID>()

        for inst in design.componentInstances {
            guard let symbolDef = inst.symbolInstance.definition else { continue }

            let ownerPosition = inst.symbolInstance.position
            let ownerRotation = inst.symbolInstance.rotation

            for pinDef in symbolDef.pins {
                let pinID = GraphPinID.makeID(ownerID: inst.id, pinID: pinDef.id)
                let nodeID = NodeID(pinID)
                let component = CanvasPin(
                    pin: pinDef,
                    ownerID: inst.id,
                    ownerPosition: ownerPosition,
                    ownerRotation: ownerRotation,
                    layerId: nil,
                    isSelectable: false
                )

                if !graph.nodes.contains(nodeID) {
                    graph.addNode(nodeID)
                }
                graph.setComponent(component, for: nodeID)
                updatedIDs.insert(nodeID)
            }
        }

        let existingIDs = Set(graph.nodeIDs(with: CanvasPin.self))
        for id in existingIDs.subtracting(updatedIDs) {
            graph.removeComponent(CanvasPin.self, for: id)
            if !graph.hasAnyComponent(for: id) {
                graph.removeNode(id)
            }
        }
    }

    private func handleStoreDelta(_ delta: CanvasStoreDelta) {
        switch delta {
        case .selectionChanged(let selection):
            guard !suppressGraphSelectionSync else { return }
            let graphSelection = Set(
                selection.compactMap { id -> NodeID? in
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

    private func handleGraphDelta(_ delta: UnifiedGraphDelta) {
        switch delta {
        case .selectionChanged(let selection):
            guard !suppressGraphSelectionSync else { return }
            let graphSelectionIDs = Set(selection.map { $0.rawValue })
            if canvasStore.selection != graphSelectionIDs {
                suppressGraphSelectionSync = true
                Task { @MainActor in
                    self.canvasStore.selection = graphSelectionIDs
                    self.suppressGraphSelectionSync = false
                }
            }
        case .componentSet(let id, let componentKey):
            if componentKey == ObjectIdentifier(CanvasText.self),
                let component = graph.component(CanvasText.self, for: id),
                !isSyncingTextFromModel
            {
                applyGraphTextChange(component)
            }
            canvasStore.invalidate()
        case .nodeRemoved:
            canvasStore.invalidate()
        case .nodeAdded:
            canvasStore.invalidate()
        case .componentRemoved:
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

        isApplyingTextChangesToModel = true
        inst.apply(component.resolvedText, for: component.target)
        document.scheduleAutosave()
        isApplyingTextChangesToModel = false
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
        return true
    }
}
