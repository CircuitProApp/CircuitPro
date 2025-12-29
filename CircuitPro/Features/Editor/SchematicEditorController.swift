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
    private var isSyncingSymbolsFromModel = false

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
                self.refreshSymbolComponents()
                self.refreshSymbolTextNodes()
                self.refreshSymbolPinComponents()
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

        // Load symbol components
        refreshSymbolComponents()
        refreshSymbolTextNodes()
        refreshSymbolPinComponents()
        canvasStore.invalidate()
    }

    // MARK: - Symbol Refresh (when structure changes)

    private func refreshSymbols() async {
        refreshSymbolComponents()
        refreshSymbolTextNodes()
        refreshSymbolPinComponents()

        // Also sync pins when symbols change (component added/moved)
        // Use the loading flag to prevent persistence during sync
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
        isSyncingSymbolsFromModel = true
        var updatedIDs = Set<NodeID>()

        for inst in design.componentInstances {
            guard let symbolDef = inst.symbolInstance.definition else { continue }
            let nodeID = NodeID(inst.id)
            let component = GraphSymbolComponent(
                ownerID: inst.id,
                position: inst.symbolInstance.position,
                rotation: inst.symbolInstance.rotation,
                primitives: symbolDef.primitives
            )
            if !graph.nodes.contains(nodeID) {
                graph.addNode(nodeID)
            }
            graph.setComponent(component, for: nodeID)
            updatedIDs.insert(nodeID)
        }

        let existingIDs = Set(graph.nodeIDs(with: GraphSymbolComponent.self))
        for id in existingIDs.subtracting(updatedIDs) {
            graph.removeComponent(GraphSymbolComponent.self, for: id)
            if !graph.hasAnyComponent(for: id) {
                graph.removeNode(id)
            }
        }

        isSyncingSymbolsFromModel = false
    }

    func refreshSymbolTextNodes() {
        let design = projectManager.selectedDesign
        isSyncingTextFromModel = true
        var updatedIDs = Set<NodeID>()

        for inst in design.componentInstances {
            let ownerPosition = inst.symbolInstance.position
            let ownerRotation = inst.symbolInstance.rotation
            let ownerTransform = CGAffineTransform(
                translationX: ownerPosition.x, y: ownerPosition.y
            )
            .rotated(by: ownerRotation)

            for resolvedModel in inst.symbolInstance.resolvedItems {
                let displayString = projectManager.generateString(
                    for: resolvedModel, component: inst)
                let textID = GraphTextID.makeID(
                    for: resolvedModel.source, ownerID: inst.id, fallback: resolvedModel.id)
                let nodeID = NodeID(textID)

                let worldPosition = resolvedModel.relativePosition.applying(ownerTransform)
                let worldAnchorPosition = resolvedModel.anchorPosition.applying(ownerTransform)
                let worldRotation = ownerRotation + resolvedModel.cardinalRotation.radians

                let component = GraphTextComponent(
                    resolvedText: resolvedModel,
                    displayText: displayString,
                    ownerID: inst.id,
                    target: .symbol,
                    ownerPosition: ownerPosition,
                    ownerRotation: ownerRotation,
                    worldPosition: worldPosition,
                    worldRotation: worldRotation,
                    worldAnchorPosition: worldAnchorPosition,
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

        let existingIDs = Set(graph.nodeIDs(with: GraphTextComponent.self))
        for id in existingIDs.subtracting(updatedIDs) {
            graph.removeComponent(GraphTextComponent.self, for: id)
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
                let component = GraphPinComponent(
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

        let existingIDs = Set(graph.nodeIDs(with: GraphPinComponent.self))
        for id in existingIDs.subtracting(updatedIDs) {
            graph.removeComponent(GraphPinComponent.self, for: id)
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
            if componentKey == ObjectIdentifier(GraphTextComponent.self),
                let component = graph.component(GraphTextComponent.self, for: id),
                !isSyncingTextFromModel
            {
                applyGraphTextChange(component)
            } else if componentKey == ObjectIdentifier(GraphSymbolComponent.self),
                let component = graph.component(GraphSymbolComponent.self, for: id),
                !isSyncingSymbolsFromModel
            {
                applyGraphSymbolChange(component)
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

    private func applyGraphTextChange(_ component: GraphTextComponent) {
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

    private func applyGraphSymbolChange(_ component: GraphSymbolComponent) {
        guard
            let inst = projectManager.componentInstances.first(where: { $0.id == component.ownerID }
            )
        else { return }
        inst.symbolInstance.position = component.position
        inst.symbolInstance.rotation = component.rotation
        document.scheduleAutosave()
    }

    func symbolBinding(for id: UUID) -> Binding<GraphSymbolComponent>? {
        let nodeID = NodeID(id)
        guard graph.component(GraphSymbolComponent.self, for: nodeID) != nil else { return nil }
        return Binding(
            get: { self.graph.component(GraphSymbolComponent.self, for: nodeID)! },
            set: { newValue in
                if !self.graph.nodes.contains(nodeID) {
                    self.graph.addNode(nodeID)
                }
                self.graph.setComponent(newValue, for: nodeID)
            }
        )
    }

    func textBinding(for id: UUID) -> Binding<GraphTextComponent>? {
        let nodeID = NodeID(id)
        guard graph.component(GraphTextComponent.self, for: nodeID) != nil else { return nil }
        return Binding(
            get: { self.graph.component(GraphTextComponent.self, for: nodeID)! },
            set: { newValue in
                self.setTextComponent(newValue, for: nodeID)
            }
        )
    }

    private func setTextComponent(_ component: GraphTextComponent, for id: NodeID) {
        var updated = component
        let ownerTransform = component.ownerTransform
        updated.worldPosition = component.resolvedText.relativePosition.applying(ownerTransform)
        updated.worldAnchorPosition = component.resolvedText.anchorPosition.applying(ownerTransform)
        updated.worldRotation =
            component.ownerRotation + component.resolvedText.cardinalRotation.radians
        if !graph.nodes.contains(id) {
            graph.addNode(id)
        }
        graph.setComponent(updated, for: id)
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
