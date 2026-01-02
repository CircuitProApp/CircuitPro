import Observation
import SwiftUI

/// The high-level controller for the layout editor.
///
/// This class is the single source of truth for the layout canvas's view state. It observes the
/// core `ProjectManager` data and is responsible for building the renderable item list
/// of footprints and traces. It also manages layout-specific UI state like the active layer.
@MainActor
@Observable
final class LayoutEditorController: EditorController {

    // MARK: - EditorController Conformance

    var items: [any CanvasItem] = []

    let graph = CanvasGraph()
    private var activeDesignID: UUID?
    private var isSyncingTracesFromModel = false
    private var isApplyingTraceChangesToModel = false
    private var cachedFootprintTransforms: [UUID: FootprintTransform] = [:]

    // MARK: - Layout-Specific State

    /// The ID of the currently active layer for editing (e.g., for routing traces).
    var activeLayerId: UUID? = nil

    /// The list of layers relevant to the current design's layout, sorted for rendering.
    var canvasLayers: [CanvasLayer] = []

    /// The engine for managing layout traces in the unified graph.
    let traceEngine: TraceEngine

    var selectedTool: CanvasTool = CursorTool()

    // MARK: - Dependencies

    @ObservationIgnored private let projectManager: ProjectManager
    @ObservationIgnored private let document: CircuitProjectFileDocument

    private struct FootprintTransform: Equatable {
        let position: CGPoint
        let rotation: CardinalRotation
    }

    init(projectManager: ProjectManager) {
        self.projectManager = projectManager
        self.document = projectManager.document
        self.traceEngine = TraceEngine(graph: graph)
        self.traceEngine.onChange = { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.handleTraceEngineChange()
            }
        }

        // Start the automatic observation loops upon initialization.
        startTrackingStructureChanges()
        startTrackingTextChanges()
        startTrackingTransformChanges()
        startTrackingTraceChanges()

        Task {
            await self.rebuildItems()
        }
    }

    private func startTrackingStructureChanges() {
        withObservationTracking {
            // Rebuild layout nodes if the design or its components change.
            _ = projectManager.selectedDesign
            _ = projectManager.componentInstances
            _ = projectManager.selectedDesign.layers
            for comp in projectManager.componentInstances {
                if let footprint = comp.footprintInstance {
                    _ = footprint.placement
                    _ = footprint.definitionUUID
                }
            }
        } onChange: {
            Task { @MainActor in
                await self.rebuildItems()
                self.startTrackingStructureChanges()
            }
        }
    }

    private func startTrackingTextChanges() {
        withObservationTracking {
            _ = projectManager.syncManager.pendingChanges
            // Track nested data that affects footprint text rendering.
            for comp in projectManager.componentInstances {
                _ = comp.propertyOverrides
                _ = comp.propertyInstances
                _ = comp.referenceDesignatorIndex
                if let fp = comp.footprintInstance {
                    _ = fp.textOverrides
                    _ = fp.textInstances
                    _ = fp.resolvedItems
                }
            }
        } onChange: {
            Task { @MainActor in
                self.refreshFootprintTextItems()
                self.startTrackingTextChanges()
            }
        }
    }

    private func startTrackingTransformChanges() {
        withObservationTracking {
            for comp in projectManager.componentInstances {
                if let fp = comp.footprintInstance {
                    _ = fp.position
                    _ = fp.cardinalRotation
                }
            }
        } onChange: {
            Task { @MainActor in
                var nextCache: [UUID: FootprintTransform] = [:]
                var updatedItems = self.items
                var didUpdate = false
                for comp in self.projectManager.componentInstances {
                    guard let fp = comp.footprintInstance,
                        case .placed = fp.placement
                    else {
                        continue
                    }
                    let transform = FootprintTransform(
                        position: fp.position,
                        rotation: fp.cardinalRotation
                    )
                    if self.cachedFootprintTransforms[comp.id] != transform {
                        self.updateOwnerTransform(
                            ownerID: comp.id,
                            position: fp.position,
                            rotation: fp.rotation,
                            items: &updatedItems
                        )
                        didUpdate = true
                    }
                    nextCache[comp.id] = transform
                }
                self.cachedFootprintTransforms = nextCache
                if didUpdate {
                    self.items = updatedItems
                }
                self.startTrackingTransformChanges()
            }
        }
    }

    private func startTrackingTraceChanges() {
        withObservationTracking {
            _ = projectManager.selectedDesign.traces
        } onChange: {
            Task { @MainActor in
                if self.isApplyingTraceChangesToModel {
                    self.isApplyingTraceChangesToModel = false
                    self.startTrackingTraceChanges()
                    return
                }
                self.syncTracesFromModel()
                self.startTrackingTraceChanges()
            }
        }
    }

    // MARK: - Item Building

    /// The primary method to rebuild the item list. It's called automatically by the tracking system.
    private func rebuildItems() async {
        let design = projectManager.selectedDesign
        resetGraphIfNeeded(for: design)

        // 1. Rebuild and sort the canvas layers for this design.
        let unsortedCanvasLayers = design.layers.map { layerType in
            CanvasLayer(
                id: layerType.id,
                name: layerType.name,
                isVisible: true,
                color: NSColor(layerType.defaultColor).cgColor,
                zIndex: layerType.kind.zIndex,
                kind: layerType
            )
        }

        self.canvasLayers = unsortedCanvasLayers.sorted { (layerA, layerB) -> Bool in
            if layerA.zIndex != layerB.zIndex {
                return layerA.zIndex < layerB.zIndex
            }
            guard let typeA = layerA.kind as? LayerType, let sideA = typeA.side,
                let typeB = layerB.kind as? LayerType, let sideB = typeB.side
            else {
                return false
            }
            return sideA.drawingOrder < sideB.drawingOrder
        }

        syncTracesFromModel()
        items = buildItems(from: design)
    }

    private func buildItems(from design: CircuitDesign) -> [any CanvasItem] {
        var result: [any CanvasItem] = []

        for inst in design.componentInstances {
            guard let footprintInst = inst.footprintInstance,
                case .placed = footprintInst.placement,
                let footprintDef = footprintInst.definition
            else {
                continue
            }

            let primitives = resolveFootprintPrimitives(
                for: footprintInst, definition: footprintDef)
            let footprint = CanvasFootprint(
                ownerID: inst.id,
                footprint: footprintInst,
                primitives: primitives
            )
            result.append(footprint)

            let ownerPosition = footprintInst.position
            let ownerRotation = footprintInst.rotation

            for resolvedModel in footprintInst.resolvedItems {
                let displayString = projectManager.generateString(
                    for: resolvedModel, component: inst)
                let text = CanvasText(
                    resolvedText: resolvedModel,
                    displayText: displayString,
                    ownerID: inst.id,
                    target: .footprint,
                    ownerPosition: ownerPosition,
                    ownerRotation: ownerRotation,
                    layerId: nil,
                    showsAnchorGuides: true
                )
                result.append(text)
            }

            for padDef in footprintDef.pads {
                let pad = CanvasPad(
                    pad: padDef,
                    ownerID: inst.id,
                    ownerPosition: ownerPosition,
                    ownerRotation: ownerRotation,
                    layerId: nil,
                    isSelectable: false
                )
                result.append(pad)
            }
        }

        return result
    }

    private func resolveFootprintPrimitives(
        for instance: FootprintInstance, definition: FootprintDefinition
    ) -> [AnyCanvasPrimitive] {
        guard case .placed(let side) = instance.placement else {
            return definition.primitives
        }

        return definition.primitives.map { primitive in
            var copy = primitive
            guard let genericLayerID = copy.layerId,
                let genericKind = LayerKind.allCases.first(where: { $0.stableId == genericLayerID })
            else {
                return copy
            }

            if let specificLayer = canvasLayers.first(where: { canvasLayer in
                guard let layerType = canvasLayer.kind as? LayerType else { return false }
                let kindMatches = layerType.kind == genericKind
                let sideMatches =
                    (side == .front && layerType.side == .front)
                    || (side == .back && layerType.side == .back)
                return kindMatches && sideMatches
            }) {
                copy.layerId = specificLayer.id
            }

            return copy
        }
    }

    func refreshFootprintTextItems() {
        let design = projectManager.selectedDesign
        var updatedItems: [any CanvasItem] = items.filter { item in
            guard let text = item as? CanvasText else { return true }
            return text.target != .footprint
        }

        for inst in design.componentInstances {
            guard let footprintInst = inst.footprintInstance,
                case .placed = footprintInst.placement
            else {
                continue
            }

            let ownerPosition = footprintInst.position
            let ownerRotation = footprintInst.rotation

            for resolvedModel in footprintInst.resolvedItems {
                let displayString = projectManager.generateString(
                    for: resolvedModel, component: inst)

                let component = CanvasText(
                    resolvedText: resolvedModel,
                    displayText: displayString,
                    ownerID: inst.id,
                    target: .footprint,
                    ownerPosition: ownerPosition,
                    ownerRotation: ownerRotation,
                    layerId: nil,
                    showsAnchorGuides: true
                )

                updatedItems.append(component)
            }
        }

        items = updatedItems
    }

    // MARK: - Private Helpers
    private func updateOwnerTransform(
        ownerID: UUID,
        position: CGPoint,
        rotation: CGFloat,
        items: inout [any CanvasItem]
    ) {
        for index in items.indices {
            if var footprint = items[index] as? CanvasFootprint, footprint.ownerID == ownerID {
                footprint.position = position
                footprint.rotation = rotation
                items[index] = footprint
            } else if var pad = items[index] as? CanvasPad, pad.ownerID == ownerID {
                pad.ownerPosition = position
                pad.ownerRotation = rotation
                items[index] = pad
            } else if var text = items[index] as? CanvasText, text.ownerID == ownerID {
                text.ownerPosition = position
                text.ownerRotation = rotation
                items[index] = text
            }
        }
    }

    func footprintBinding(for id: UUID) -> Binding<CanvasFootprint>? {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        guard items[index] is CanvasFootprint else { return nil }
        return Binding(
            get: {
                guard let currentIndex = self.items.firstIndex(where: { $0.id == id }),
                    let current = self.items[currentIndex] as? CanvasFootprint
                else {
                    return self.items[index] as! CanvasFootprint
                }
                return current
            },
            set: { newValue in
                guard let currentIndex = self.items.firstIndex(where: { $0.id == id }) else { return }
                self.items[currentIndex] = newValue
            }
        )
    }

    func textBinding(for id: UUID) -> Binding<CanvasText>? {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        guard items[index] is CanvasText else { return nil }
        return Binding(
            get: {
                guard let currentIndex = self.items.firstIndex(where: { $0.id == id }),
                    let current = self.items[currentIndex] as? CanvasText
                else {
                    return self.items[index] as! CanvasText
                }
                return current
            },
            set: { newValue in
                guard let currentIndex = self.items.firstIndex(where: { $0.id == id }) else { return }
                self.items[currentIndex] = newValue
                if let inst = self.projectManager.componentInstances.first(
                    where: { $0.id == newValue.ownerID }
                ) {
                    inst.apply(newValue.resolvedText, for: newValue.target)
                    self.document.scheduleAutosave()
                }
            }
        )
    }

    private func resetGraphIfNeeded(for design: CircuitDesign) {
        guard activeDesignID != design.id else { return }
        activeDesignID = design.id
        isSyncingTracesFromModel = true
        traceEngine.reset()
        isSyncingTracesFromModel = false
        graph.reset()
    }

    private func handleTraceEngineChange() {
        persistTraces()
    }

    private func persistTraces() {
        guard !isSyncingTracesFromModel else { return }
        let design = projectManager.selectedDesign
        let newTraces = traceEngine.toTraceSegments()
        let existing = design.traces.map { $0.normalized() }.sorted { $0.sortKey < $1.sortKey }
        if newTraces == existing {
            return
        }
        isApplyingTraceChangesToModel = true
        design.traces = newTraces
        document.scheduleAutosave()
    }

    private func syncTracesFromModel() {
        isSyncingTracesFromModel = true
        let design = projectManager.selectedDesign
        let normalized = design.traces.map { $0.normalized() }
        traceEngine.build(from: normalized)
        isSyncingTracesFromModel = false
    }
}
