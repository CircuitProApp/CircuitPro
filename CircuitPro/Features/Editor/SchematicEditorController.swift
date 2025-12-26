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

    let graph = CanvasGraph()
    let wireEngine: WireEngine
    private var suppressGraphSelectionSync = false
    private var isSyncingWiresFromModel = false
    private var isApplyingWireChangesToModel = false
    private var isSyncingTextFromModel = false
    private var isApplyingTextChangesToModel = false

    init(projectManager: ProjectManager) {
        self.projectManager = projectManager
        self.document = projectManager.document
        self.wireEngine = WireEngine(graph: graph)
        self.nodeProvider = SchematicNodeProvider(wireEngine: self.wireEngine)
        self.wireEngine.onChange = { [weak self] in
            Task { @MainActor in
                self?.persistGraph()
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
        startTrackingWireChanges()

        Task {
            await self.rebuildNodes()
        }
    }

    private func startTrackingStructureChanges() {
        withObservationTracking {
            _ = projectManager.selectedDesign
            _ = projectManager.componentInstances
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
                _ = comp.symbolInstance.position
                _ = comp.symbolInstance.cardinalRotation
            }
        } onChange: {
            Task { @MainActor in
                self.refreshSymbolTextNodes()
                self.startTrackingTextChanges()
            }
        }
    }

    private func startTrackingWireChanges() {
        withObservationTracking {
            _ = projectManager.selectedDesign.wires
        } onChange: {
            Task { @MainActor in
                if self.isApplyingWireChangesToModel {
                    self.isApplyingWireChangesToModel = false
                    self.startTrackingWireChanges()
                    return
                }
                self.syncWiresFromModel()
                self.startTrackingWireChanges()
            }
        }
    }

    private func rebuildNodes() async {
        let design = projectManager.selectedDesign

        // This is where the graph is automatically synced on every rebuild.
        let context = BuildContext(activeLayers: [])
        canvasStore.setNodes(await nodeProvider.buildNodes(from: design, context: context))
        syncWiresFromModel()
        refreshSymbolTextNodes()
    }

    func refreshSymbolTextNodes() {
        let design = projectManager.selectedDesign
        isSyncingTextFromModel = true
        var updatedIDs = Set<NodeID>()

        for inst in design.componentInstances {
            let ownerPosition = inst.symbolInstance.position
            let ownerRotation = inst.symbolInstance.rotation
            let ownerTransform = CGAffineTransform(translationX: ownerPosition.x, y: ownerPosition.y)
                .rotated(by: ownerRotation)

            for resolvedModel in inst.symbolInstance.resolvedItems {
                let displayString = projectManager.generateString(for: resolvedModel, component: inst)
                let textID = GraphTextID.makeID(for: resolvedModel.source, ownerID: inst.id, fallback: resolvedModel.id)
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
        canvasStore.setNodes(canvasStore.nodes, emitDelta: false)
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

    private func handleGraphDelta(_ delta: UnifiedGraphDelta) {
        switch delta {
        case .selectionChanged(let selection):
            guard !suppressGraphSelectionSync else { return }
            let graphSelectionIDs = Set(selection.map { $0.rawValue })
            let nonGraphSelection = canvasStore.selection.filter { id in
                !graph.hasAnyComponent(for: NodeID(id))
            }
            let mergedSelection = Set(nonGraphSelection).union(graphSelectionIDs)
            if canvasStore.selection != mergedSelection {
                suppressGraphSelectionSync = true
                Task { @MainActor in
                    self.canvasStore.selection = mergedSelection
                    self.suppressGraphSelectionSync = false
                }
            }
        case .componentSet(let id, let componentKey):
            if componentKey == ObjectIdentifier(GraphTextComponent.self),
               let component = graph.component(GraphTextComponent.self, for: id),
               !isSyncingTextFromModel {
                applyGraphTextChange(component)
            }
        default:
            break
        }
    }

    private func applyGraphTextChange(_ component: GraphTextComponent) {
        guard !isApplyingTextChangesToModel else { return }
        guard let inst = projectManager.componentInstances.first(where: { $0.id == component.ownerID }) else { return }

        isApplyingTextChangesToModel = true
        inst.apply(component.resolvedText, for: component.target)
        document.scheduleAutosave()
        isApplyingTextChangesToModel = false
    }

    func findNode(with id: UUID) -> BaseNode? {
        return canvasStore.nodes.findNode(with: id)
    }

    private func persistGraph() {
        guard !isSyncingWiresFromModel else { return }
        let design = projectManager.selectedDesign
        let newWires = wireEngine.toWires()
        guard newWires != design.wires else { return }
        isApplyingWireChangesToModel = true
        design.wires = newWires
        document.scheduleAutosave()
    }

    private func syncWiresFromModel() {
        isSyncingWiresFromModel = true
        let design = projectManager.selectedDesign
        wireEngine.build(from: design.wires)
        for inst in design.componentInstances {
            guard let symbolDef = inst.definition?.symbol else { continue }
            wireEngine.syncPins(for: inst.symbolInstance, of: symbolDef, ownerID: inst.id)
        }
        isSyncingWiresFromModel = false
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
