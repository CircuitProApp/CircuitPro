import SwiftUI
import Observation

/// A helper to map the editor context to the change source for recording.
extension EditorType {
    var changeSource: ChangeSource {
        switch self {
        case .schematic:
            return .schematic
        case .layout:
            return .layout
        }
    }
}

/// A temporary struct that pairs the resolved data model with its generated display string,
/// for use during a single canvas rebuild operation.
struct RenderableText {
    let model: CircuitText.Resolved
    let text: String
}

@MainActor
@Observable
final class ProjectManager {
    
    var project: CircuitProject
    var selectedDesign: CircuitDesign? {
        didSet { activeLayerId = nil }
    }
    var selectedNodeIDs: Set<UUID> = []
    
    var schematicCanvasNodes: [BaseNode] = []
    var layoutCanvasNodes: [BaseNode] = []
    
    var selectedNetIDs: Set<UUID> = []
    
    var selectedEditor: EditorType = .schematic
    
    var selectedTool: CanvasTool = CursorTool()
    
    var schematicGraph = WireGraph()
    var traceGraph = TraceGraph()
    
    var activeLayerId: UUID? = nil
    
    // The SyncManager orchestrates change handling (Manual ECO).
    var syncManager: SyncManager
    
    var activeCanvasLayers: [CanvasLayer] = []
    
    /// Note: `syncManager` is optional with a nil default to avoid constructing a @MainActor
    /// type in a nonisolated default-argument context. We initialize it inside the body.
    init(
        project: CircuitProject,
        selectedDesign: CircuitDesign? = nil,
        syncManager: SyncManager? = nil
    ) {
        self.project        = project
        self.selectedDesign = selectedDesign
        self.syncManager    = syncManager ?? SyncManager()
    }
    
    var activeCanvasNodes: [BaseNode] {
        get {
            switch selectedEditor {
            case .schematic:
                return schematicCanvasNodes
            case .layout:
                return layoutCanvasNodes
            }
        }
        set {
            switch selectedEditor {
            case .schematic:
                schematicCanvasNodes = newValue
            case .layout:
                layoutCanvasNodes = newValue
            }
        }
    }
    
    var componentInstances: [ComponentInstance] {
        get { selectedDesign?.componentInstances ?? [] }
        set { selectedDesign?.componentInstances = newValue }
    }
    
    func persistSchematicGraph() {
        guard selectedDesign != nil else { return }
        selectedDesign?.wires = schematicGraph.toWires()
    }

    func persistTraceGraph() {
        print("Fake persisting TraceGraph...")
    }

    func handleNewNode(_ node: BaseNode) {
        if let traceRequest = node as? TraceRequestNode {
            traceGraph.addTrace(
                path: traceRequest.points,
                width: traceRequest.width,
                layerId: traceRequest.layerId
            )
            persistTraceGraph()
            rebuildLayoutNodes()
        }
    }
    
    // MARK: - Property Management
    
    /// Records a property update. In Manual ECO, uses the current resolved value as the "old" baseline
    /// and records the change into the session-aware history.
    func updateProperty(for component: ComponentInstance, with editedProperty: Property.Resolved, sessionID: UUID? = nil) {
        switch syncManager.syncMode {
        case .automatic:
            component.apply(editedProperty)
            rebuildActiveCanvasNodes()
        case .manualECO:
            // Use the resolved current value (model + latest pending) as baseline.
            guard let oldResolved = resolvedProperty(for: component, propertyID: editedProperty.id) else {
                print("Error: Could not resolve original property state to create change record for \(editedProperty.key.label).")
                return
            }
            // No-op if nothing effectively changed.
            guard editedProperty.value != oldResolved.value || editedProperty.unit != oldResolved.unit else {
                return
            }
            let payload = ChangeType.updateProperty(
                componentID: component.id,
                newProperty: editedProperty,
                oldProperty: oldResolved
            )
            syncManager.recordChange(source: selectedEditor.changeSource, payload: payload, sessionID: sessionID)
        }
    }
    
    /// Applies a list of pending changes to the main data model.
    /// This is the commit step for the Manual ECO workflow.
    /// - Parameter records: The array of `ChangeRecord`s to apply.
    /// - Parameter allFootprints: A complete list of available footprints to resolve UUIDs.
    func applyChanges(_ records: [ChangeRecord], allFootprints: [FootprintDefinition]) {
        // We process in reverse to handle cases where multiple changes affect one component.
        // The last record in time (first in our array) should be the final state.
        for record in records.reversed() {
            guard let component = componentInstances.first(where: {
                switch record.payload {
                case .updateReferenceDesignator(let id, _, _),
                     .assignFootprint(let id, _, _, _),
                     .updateProperty(let id, _, _):
                    return $0.id == id
                }
            }) else {
                print("Warning: Could not find component for change record \(record.id). Skipping.")
                continue
            }
            
            // Apply the change based on its type
            switch record.payload {
            case .updateReferenceDesignator(_, let newIndex, _):
                component.referenceDesignatorIndex = newIndex
                
            case .updateProperty(_, let newProperty, _):
                component.apply(newProperty)
                
            case .assignFootprint(_, let newFootprintUUID, _, _):
                if let newFootprintUUID = newFootprintUUID {
                    // Find the full footprint definition from the provided list.
                    guard let footprintDef = allFootprints.first(where: { $0.uuid == newFootprintUUID }) else {
                        print("Warning: Could not find footprint definition for UUID \(newFootprintUUID). Skipping.")
                        continue
                    }
                    
                    // --- "Smart Sync" Logic ---
                    // Preserve the existing placement if one exists.
                    let oldPlacement = component.footprintInstance?.placement ?? .unplaced
                    let oldPosition = component.footprintInstance?.position ?? .zero
                    let oldRotation = component.footprintInstance?.rotation ?? 0
                    
                    let newFootprintInstance = FootprintInstance(
                        definitionUUID: footprintDef.uuid,
                        definition: footprintDef,
                        placement: oldPlacement
                    )
                    newFootprintInstance.position = oldPosition
                    newFootprintInstance.rotation = oldRotation
                    
                    component.footprintInstance = newFootprintInstance
                    
                } else {
                    // The change was to un-assign the footprint.
                    component.footprintInstance = nil
                }
            }
        }
        
        // After all changes are applied, clear the pending list.
        syncManager.clearChanges()
        
        // Finally, trigger a full UI rebuild to show the committed changes.
        rebuildActiveCanvasNodes()
    }
    
    /// Applies a specific subset of pending changes identified by their IDs.
    func applyChanges(withIDs ids: Set<UUID>, allFootprints: [FootprintDefinition]) {
        let recordsToApply = syncManager.pendingChanges.filter { ids.contains($0.id) }
        
        // We can reuse our existing apply logic!
        applyChanges(recordsToApply, allFootprints: allFootprints)
        
        // But we only remove the ones we applied.
        syncManager.removeChanges(withIDs: ids)
    }

    /// Discards a specific subset of pending changes identified by their IDs.
    func discardChanges(withIDs ids: Set<UUID>) {
        syncManager.removeChanges(withIDs: ids)
        rebuildActiveCanvasNodes() // Rebuild to revert the UI
    }

    
    func addProperty(_ newProperty: Property.Instance, to component: ComponentInstance) {
        switch syncManager.syncMode {
        case .automatic:
            component.add(newProperty)
            rebuildActiveCanvasNodes()
        case .manualECO:
            // TODO: Requires a new ChangeType case, e.g., `.addProperty(componentID: UUID, property: Property.Instance)`
            print("MANUAL ECO: Add property action recorded (conceptual).")
        }
    }
    
    func removeProperty(_ propertyToRemove: Property.Resolved, from component: ComponentInstance) {
        switch syncManager.syncMode {
        case .automatic:
            component.remove(propertyToRemove)
            rebuildActiveCanvasNodes()
        case .manualECO:
            // TODO: Requires a new ChangeType case, e.g., `.removeProperty(componentID: UUID, property: Property.Resolved)`
            print("MANUAL ECO: Remove property action recorded (conceptual).")
        }
    }
    
    func discardPendingChanges() {
        // Step 1: Tell the SyncManager to clear its list of pending changes.
        syncManager.clearChanges()
        
        // Step 2: Force a full UI rebuild. This is critical to ensure that
        // inspector views revert from showing "pending" values back to the
        // original values from the main data model.
        rebuildActiveCanvasNodes()
    }

    // MARK: - Text Management
    
    func toggleDynamicTextVisibility(for component: ComponentInstance, content: CircuitTextContent) {
        if let textToToggle = component.symbolInstance.resolvedItems.first(where: { $0.content.isSameType(as: content) }) {
            var editedText = textToToggle
            editedText.isVisible.toggle()
            updateText(for: component, with: editedText)
        } else {
            let existingTextPositions = component.symbolInstance.resolvedItems.map(\.relativePosition)
            let lowestY = existingTextPositions.map(\.y).min() ?? -20
            let newPosition = CGPoint(x: 0, y: lowestY - 10)
            
            let newTextInstance = CircuitText.Instance(
                content: content,
                relativePosition: newPosition,
                anchorPosition: newPosition
            )
            addText(newTextInstance, to: component)
        }
    }
    
    func togglePropertyVisibility(for component: ComponentInstance, property: Property.Resolved) {
        guard case .definition(let propertyDef) = property.source else {
            print("Error: Visibility can only be toggled for definition-based properties.")
            return
        }
        
        let defaultOptions = component.definition?.symbol?.textDefinitions
            .first(where: { $0.content.isSameType(as: .componentProperty(definitionID: propertyDef.id, options: .default)) })?
            .content.displayOptions ?? .default
        
        let contentToToggle = CircuitTextContent.componentProperty(definitionID: propertyDef.id, options: defaultOptions)
        toggleDynamicTextVisibility(for: component, content: contentToToggle)
    }
    
    func updateText(for component: ComponentInstance, with editedText: CircuitText.Resolved) {
        // MODIFIED: Text changes are visual and should always be applied directly, bypassing the ECO system.
        component.apply(editedText)
        rebuildActiveCanvasNodes()
    }

    func addText(_ newText: CircuitText.Instance, to component: ComponentInstance) {
        // MODIFIED: Adding text is a visual change and should always be applied directly.
        component.add(newText)
        rebuildActiveCanvasNodes()
    }

    func removeText(_ textToRemove: CircuitText.Resolved, from component: ComponentInstance) {
        // MODIFIED: Removing text is a visual change and should always be applied directly.
        component.remove(textToRemove)
        rebuildActiveCanvasNodes()
    }

    // MARK: - Other Component Actions
    
    /// Records a reference designator change. In Manual ECO, uses the resolved current index as "old".
    func updateReferenceDesignator(for component: ComponentInstance, newIndex: Int, sessionID: UUID? = nil) {
        switch syncManager.syncMode {
        case .automatic:
            component.referenceDesignatorIndex = newIndex
            rebuildActiveCanvasNodes()
        case .manualECO:
            let oldIndex = resolvedReferenceDesignator(for: component) // resolved baseline
            guard newIndex != oldIndex else { return }
            let payload = ChangeType.updateReferenceDesignator(
                componentID: component.id,
                newIndex: newIndex,
                oldIndex: oldIndex
            )
            syncManager.recordChange(source: selectedEditor.changeSource, payload: payload, sessionID: sessionID)
        }
    }
    
    /// Records a footprint assignment change. In Manual ECO, uses the resolved current name as "old".
    func assignFootprint(to component: ComponentInstance, footprint: FootprintDefinition?, sessionID: UUID? = nil) {
        switch syncManager.syncMode {
        case .automatic:
            if let footprint = footprint {
                let newFootprintInstance = FootprintInstance(
                    definitionUUID: footprint.uuid,
                    definition: footprint,
                    placement: .unplaced
                )
                component.footprintInstance = newFootprintInstance
            } else {
                component.footprintInstance = nil
            }
            rebuildActiveCanvasNodes()
        case .manualECO:
            let oldName = resolvedFootprintName(for: component) // resolved baseline
            let payload = ChangeType.assignFootprint(
                componentID: component.id,
                newFootprintUUID: footprint?.uuid,
                newFootprintName: footprint?.name,
                oldFootprintName: oldName
            )
            syncManager.recordChange(source: selectedEditor.changeSource, payload: payload, sessionID: sessionID)
        }
    }

    func placeComponent(instanceID: UUID, at location: CGPoint, on side: BoardSide) {
        guard let component = componentInstances.first(where: { $0.id == instanceID }) else {
            print("Error: Could not find component instance with ID \(instanceID) to place.")
            return
        }

        switch syncManager.syncMode {
        case .automatic:
            if let footprint = component.footprintInstance {
                footprint.placement = .placed(side: side)
                footprint.position = location
            }
            rebuildLayoutNodes()
        case .manualECO:
            // TODO: Requires a new ChangeType case, e.g., `.updatePlacement(componentID: UUID, newPlacement: Placement, oldPlacement: Placement)`
            print("MANUAL ECO: Place component action for \(component.id) recorded (conceptual).")
        }
    }
    
    // MARK: - Canvas and Graph Management (Unchanged)
    
    private func makeGraph(from design: CircuitDesign) -> WireGraph {
        let newGraph = WireGraph()
        newGraph.build(from: design.wires)
        
        for inst in design.componentInstances {
            guard let symbolDef = inst.definition?.symbol else { continue }
            newGraph.syncPins(for: inst.symbolInstance, of: symbolDef, ownerID: inst.id)
        }
        return newGraph
    }
    
    private func generateRenderableTexts(for inst: ComponentInstance) -> [RenderableText] {
        return inst.symbolInstance.resolvedItems.map { resolvedModel in
            let displayString = self.generateString(for: resolvedModel, component: inst)
            return RenderableText(model: resolvedModel, text: displayString)
        }
    }

    func generateString(for resolvedText: CircuitText.Resolved, component: ComponentInstance) -> String {
        // Pending overlay policy:
        // - On schematic canvas, show schematic-origin pending values as truth.
        // - Elsewhere, show model values (no overlay).
        let overlaySource: ChangeSource? = (selectedEditor == .schematic && syncManager.syncMode == .manualECO) ? .schematic : nil

        switch resolvedText.content {
        case .static(let text):
            return text

        case .componentName:
            return component.definition?.name ?? "???"

        case .componentReferenceDesignator:
            let idx = resolvedReferenceDesignator(for: component, onlyFrom: overlaySource)
            return (component.definition?.referenceDesignatorPrefix ?? "REF?") + String(idx)

        case .componentProperty(let definitionID, let options):
            // Fetch either overlay or model property
            let prop = resolvedProperty(for: component, propertyID: definitionID, onlyFrom: overlaySource)
            guard let property = prop else { return "" }

            var parts: [String] = []
            if options.showKey { parts.append(property.key.label) }
            if options.showValue { parts.append(property.value.description) }
            if options.showUnit, !property.unit.description.isEmpty { parts.append(property.unit.description) }
            return parts.joined(separator: " ")
        }
    }
    
    func rebuildActiveCanvasNodes() {
        switch selectedEditor {
        case .schematic:
            rebuildSchematicNodes()
        case .layout:
            rebuildLayoutNodes()
        }
    }
    
    private func rebuildSchematicNodes() {
        guard let design = selectedDesign else {
            self.schematicCanvasNodes = []
            self.schematicGraph = WireGraph()
            self.activeCanvasLayers = []
            return
        }
        
        let newGraph = self.makeGraph(from: design)
        self.schematicGraph = newGraph
        
        let symbolNodes: [SymbolNode] = design.componentInstances.compactMap { inst -> SymbolNode? in
            guard inst.symbolInstance.definition != nil else { return nil }
            let renderableTexts = self.generateRenderableTexts(for: inst)
            return SymbolNode(id: inst.id, instance: inst.symbolInstance, renderableTexts: renderableTexts, graph: self.schematicGraph)
        }
        let graphNode = SchematicGraphNode(graph: self.schematicGraph)
        graphNode.syncChildNodesFromModel()
        
        self.schematicCanvasNodes = symbolNodes + [graphNode]
        self.activeCanvasLayers = []
    }
    
    private func rebuildLayoutNodes() {
        guard let design = selectedDesign else {
            self.layoutCanvasNodes = []
            self.activeCanvasLayers = []
            return
        }
        
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

        let sortedCanvasLayers = unsortedCanvasLayers.sorted { (layerA, layerB) -> Bool in
            if layerA.zIndex != layerB.zIndex {
                return layerA.zIndex < layerB.zIndex
            }
            guard let typeA = layerA.kind as? LayerType, let sideA = typeA.side,
                  let typeB = layerB.kind as? LayerType, let sideB = typeB.side else {
                return false
            }
            return sideA.drawingOrder < sideB.drawingOrder
        }
        
        self.activeCanvasLayers = sortedCanvasLayers
        
        let footprintNodes: [FootprintNode] = design.componentInstances.compactMap { inst -> FootprintNode? in
            guard let footprintInst = inst.footprintInstance,
                  case .placed = footprintInst.placement,
                  footprintInst.definition != nil else {
                return nil
            }
            let renderableTexts = self.generateRenderableTexts(for: inst)
            return FootprintNode(id: inst.id, instance: footprintInst, canvasLayers: self.activeCanvasLayers, renderableTexts: renderableTexts)
        }
        
        let traceGraphNode = TraceGraphNode(graph: self.traceGraph)
        traceGraphNode.syncChildNodesFromModel(canvasLayers: self.activeCanvasLayers)
        
        self.layoutCanvasNodes = footprintNodes + [traceGraphNode]
    }

    func upsertSymbolNode(for inst: ComponentInstance) {
        guard inst.symbolInstance.definition != nil else { return }
        
        let renderableTexts = self.generateRenderableTexts(for: inst)
        
        guard let node = SymbolNode(id: inst.id, instance: inst.symbolInstance, renderableTexts: renderableTexts, graph: self.schematicGraph) else { return }
        
        if let idx = schematicCanvasNodes.firstIndex(where: { $0.id == inst.id }) {
            schematicCanvasNodes[idx] = node
        } else if let graphIndex = schematicCanvasNodes.firstIndex(where: { $0 is SchematicGraphNode }) {
            schematicCanvasNodes.insert(node, at: graphIndex)
        } else {
            let graphNode = SchematicGraphNode(graph: self.schematicGraph)
            graphNode.syncChildNodesFromModel()
            schematicCanvasNodes = [node, graphNode]
        }
    }
}


// MARK: - Helper Extensions (Restored)

extension ComponentInstance {
    func apply(_ editedText: CircuitText.Resolved) {
        symbolInstance.apply(editedText)
    }

    func add(_ newInstance: CircuitText.Instance) {
        symbolInstance.add(newInstance)
    }

    func remove(_ textToRemove: CircuitText.Resolved) {
        symbolInstance.remove(textToRemove)
    }
}

extension CircuitTextContent {
    var displayOptions: TextDisplayOptions? {
        if case .componentProperty(_, let options) = self {
            return options
        }
        return nil
    }
}

// MARK: - Value Resolvers for UI

extension ProjectManager {
    
    /// Resolves the reference designator index for a component, considering any pending changes.
    func resolvedReferenceDesignator(for component: ComponentInstance) -> Int {
        // If we are in automatic mode, always return the model's true value.
        guard syncManager.syncMode == .manualECO else {
            return component.referenceDesignatorIndex
        }
        
        // Look for a pending change for this specific component's refdes.
        let pendingChange = syncManager.findLatestPendingChange(for: component.id) { payload in
            if case .updateReferenceDesignator = payload { return true }
            return false
        }
        
        // If a pending change was found, extract and return the new value.
        if let pendingChange, case .updateReferenceDesignator(_, let newIndex, _) = pendingChange.payload {
            return newIndex
        }
        
        // Otherwise, return the original value from the model.
        return component.referenceDesignatorIndex
    }
    
    /// Resolves the footprint name for a component, considering any pending changes.
    func resolvedFootprintName(for component: ComponentInstance) -> String? {
        guard syncManager.syncMode == .manualECO else {
            return component.footprintInstance?.definition?.name
        }
        
        let pendingChange = syncManager.findLatestPendingChange(for: component.id) { payload in
            if case .assignFootprint = payload { return true }
            return false
        }
        
        if let pendingChange, case .assignFootprint(_, _, let newFootprintName, _) = pendingChange.payload {
            return newFootprintName
        }
        
        return component.footprintInstance?.definition?.name
    }

    /// Resolves a specific property for a component, considering any pending changes.
    func resolvedProperty(for component: ComponentInstance, propertyID: UUID) -> Property.Resolved? {
        // Find the original property from the component's actual data model.
        guard let originalProperty = component.displayedProperties.first(where: { $0.id == propertyID }) else {
            return nil
        }
        
        // In automatic mode, just return the original.
        guard syncManager.syncMode == .manualECO else {
            return originalProperty
        }

        // Search for a pending change that affects this specific property.
        let pendingChange = syncManager.findLatestPendingChange(for: component.id) { payload in
            if case .updateProperty(_, let newProperty, _) = payload, newProperty.id == propertyID {
                return true
            }
            return false
        }
        
        // If a change was found, return the new property from the change record.
        if let pendingChange, case .updateProperty(_, let newProperty, _) = pendingChange.payload {
            return newProperty
        }
        
        // Otherwise, return the original.
        return originalProperty
    }
    
    func resolvedFootprintUUID(for component: ComponentInstance) -> UUID? {
        guard syncManager.syncMode == .manualECO else {
            return component.footprintInstance?.definitionUUID
        }
        
        let pendingChange = syncManager.findLatestPendingChange(for: component.id) { payload in
            if case .assignFootprint = payload { return true }
            return false
        }
        
        if let pendingChange, case .assignFootprint(_, let newFootprintUUID, _, _) = pendingChange.payload {
            return newFootprintUUID
        }
        
        return component.footprintInstance?.definitionUUID
    }
}

// MARK: - Value Resolvers for UI (source-aware)

extension ProjectManager {

    // Internal helper to find latest pending change with optional source filter
    private func latestPendingChange(
        for componentID: UUID,
        onlyFrom source: ChangeSource?,
        matches: (ChangeType) -> Bool
    ) -> ChangeRecord? {
        guard syncManager.syncMode == .manualECO else { return nil }
        return syncManager.pendingChanges.first { record in
            // Component match
            let recComponentID: UUID = {
                switch record.payload {
                case .updateReferenceDesignator(let id, _, _),
                     .assignFootprint(let id, _, _, _),
                     .updateProperty(let id, _, _):
                    return id
                }
            }()
            guard recComponentID == componentID else { return false }
            // Optional source filter
            if let source, record.source != source { return false }
            // Payload match
            return matches(record.payload)
        }
    }

    // Source-aware variants
    func resolvedReferenceDesignator(for component: ComponentInstance, onlyFrom source: ChangeSource?) -> Int {
        if let change = latestPendingChange(for: component.id, onlyFrom: source, matches: {
            if case .updateReferenceDesignator = $0 { return true }
            return false
        }),
           case .updateReferenceDesignator(_, let newIndex, _) = change.payload {
            return newIndex
        }
        return component.referenceDesignatorIndex
    }

    func resolvedFootprintName(for component: ComponentInstance, onlyFrom source: ChangeSource?) -> String? {
        if let change = latestPendingChange(for: component.id, onlyFrom: source, matches: {
            if case .assignFootprint = $0 { return true }
            return false
        }),
           case .assignFootprint(_, _, let newName, _) = change.payload {
            return newName
        }
        return component.footprintInstance?.definition?.name
    }

    func resolvedFootprintUUID(for component: ComponentInstance, onlyFrom source: ChangeSource?) -> UUID? {
        if let change = latestPendingChange(for: component.id, onlyFrom: source, matches: {
            if case .assignFootprint = $0 { return true }
            return false
        }),
           case .assignFootprint(_, let newUUID, _, _) = change.payload {
            return newUUID
        }
        return component.footprintInstance?.definitionUUID
    }

    func resolvedProperty(for component: ComponentInstance, propertyID: UUID, onlyFrom source: ChangeSource?) -> Property.Resolved? {
        // Base model value
        guard let original = component.displayedProperties.first(where: { $0.id == propertyID }) else { return nil }

        // Try pending overlay from the requested source
        if let change = latestPendingChange(for: component.id, onlyFrom: source, matches: {
            if case .updateProperty(_, let newProperty, _) = $0, newProperty.id == propertyID { return true }
            return false
        }),
           case .updateProperty(_, let newProperty, _) = change.payload {
            return newProperty
        }

        return original
    }
}

