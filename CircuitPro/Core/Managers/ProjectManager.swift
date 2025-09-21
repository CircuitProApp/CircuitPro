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
    
    // MARK: - Core Properties & State
    
    /// The document representing the file on disk. The single source of truth for the project model.
    var document: CircuitProjectFileDocument
    
    /// A convenience accessor for the underlying data model.
    var project: CircuitProject {
        document.model
    }
    
    /// The currently active design within the project.
    var selectedDesign: CircuitDesign?
    
    /// The orchestrator for change handling and resolving pending UI state (Manual ECO).
    var syncManager: SyncManager

    // MARK: - Editor Controllers
    
    /// The dedicated controller for the schematic editor. It manages all schematic-specific view state.
    /// The dedicated controller for the schematic editor. It manages all schematic-specific view state.
    /// This is a `lazy var` to break the initialization dependency cycle, as it requires `self`.
    @ObservationIgnored
    lazy var schematicController: SchematicEditorController = {
        return SchematicEditorController(projectManager: self)
    }()
    
    @ObservationIgnored
    lazy var layoutController: LayoutEditorController = {
        return LayoutEditorController(projectManager: self)
    }()
    
    // MARK: - Global UI State
    
    var selectedNodeIDs: Set<UUID> = []
    var selectedNetIDs: Set<UUID> = []
    var selectedEditor: EditorType = .schematic
    
    /// A computed property that provides direct access to the nodes of the currently active editor.
    var activeCanvasNodes: [BaseNode] {
        switch selectedEditor {
        case .schematic:
            return schematicController.nodes
        case .layout:
            // MODIFICATION 3: Get nodes from the new controller.
            return layoutController.nodes
        }
    }
    
    /// A computed property that provides the controller for the active editor.
    /// This is the primary bridge for other views (like the Inspector) to query view-specific state.
    var activeEditorController: EditorController? {
        switch selectedEditor {
        case .schematic:
            return schematicController
        case .layout:
            // MODIFICATION 4: Return the new controller.
            return layoutController
        }
    }

    init(
        document: CircuitProjectFileDocument,
        selectedDesign: CircuitDesign? = nil,
        syncManager: SyncManager? = nil
    ) {
        self.document = document
        self.selectedDesign = selectedDesign ?? document.model.designs.first
        self.syncManager = syncManager ?? SyncManager()

    }
    
    var componentInstances: [ComponentInstance] {
        get { selectedDesign?.componentInstances ?? [] }
        set { selectedDesign?.componentInstances = newValue }
    }
    
    // MARK: - Action Methods (Mutate the Data Model)
    
    func updateProperty(for component: ComponentInstance, with editedProperty: Property.Resolved, sessionID: UUID? = nil) {
        switch syncManager.syncMode {
        case .automatic:
            component.apply(editedProperty)
            document.scheduleAutosave()
        case .manualECO:
            let oldResolved = syncManager.resolvedProperty(for: component, propertyID: editedProperty.id, onlyFrom: selectedEditor.changeSource)
            guard let oldResolved = oldResolved, editedProperty.value != oldResolved.value || editedProperty.unit != oldResolved.unit else { return }
            let payload = ChangeType.updateProperty(componentID: component.id, newProperty: editedProperty, oldProperty: oldResolved)
            syncManager.recordChange(source: selectedEditor.changeSource, payload: payload, sessionID: sessionID)
        }
    }
    
    func applyChanges(_ records: [ChangeRecord], allFootprints: [FootprintDefinition]) {
        for record in records.reversed() {
            guard let component = componentInstances.first(where: { $0.id == record.payload.componentID }) else { continue }
            // Assuming ComponentInstance has an `apply(change: ChangeRecord, ...)` method
            // component.apply(change: record, allFootprints: allFootprints)
        }
        syncManager.clearChanges()
        document.scheduleAutosave()
    }
    
    func applyChanges(withIDs ids: Set<UUID>, allFootprints: [FootprintDefinition]) {
        let recordsToApply = syncManager.pendingChanges.filter { ids.contains($0.id) }
        applyChanges(recordsToApply, allFootprints: allFootprints)
        syncManager.removeChanges(withIDs: ids)
    }

    func discardChanges(withIDs ids: Set<UUID>) {
        syncManager.removeChanges(withIDs: ids)
        // No rebuild call needed; the @Observable SyncManager will trigger the controller's observer.
    }

    func discardPendingChanges() {
        syncManager.clearChanges()
        // No rebuild call needed.
    }

    func addProperty(_ newProperty: Property.Instance, to component: ComponentInstance) {
        switch syncManager.syncMode {
        case .automatic:
            component.add(newProperty)
            document.scheduleAutosave()
        case .manualECO:
            // TODO: Implement ChangeType for adding a property
            print("MANUAL ECO: Add property action not yet implemented.")
        }
    }
    
    func removeProperty(_ propertyToRemove: Property.Resolved, from component: ComponentInstance) {
        switch syncManager.syncMode {
        case .automatic:
            component.remove(propertyToRemove)
            document.scheduleAutosave()
        case .manualECO:
            // TODO: Implement ChangeType for removing a property
            print("MANUAL ECO: Remove property action not yet implemented.")
        }
    }

    func toggleDynamicTextVisibility(for component: ComponentInstance, content: CircuitTextContent) {
        // This is a visual-only change and should always be immediate.
        // It's assumed the appropriate instance (Symbol or Footprint) has a method to handle this.
      /*  component.toggleTextVisibility(content, for: selectedEditor)*/ // Assuming this helper exists
        document.scheduleAutosave()
    }
    
    func togglePropertyVisibility(for component: ComponentInstance, property: Property.Resolved) {
        // This is a schematic-specific visual change.
        guard case .definition(let propertyDef) = property.source else { return }
        let defaultOptions = component.definition?.symbol?.textDefinitions
            .first(where: { $0.content.isSameType(as: .componentProperty(definitionID: propertyDef.id, options: .default)) })?
            .content.displayOptions ?? .default
        let contentToToggle = CircuitTextContent.componentProperty(definitionID: propertyDef.id, options: defaultOptions)
//        component.toggleTextVisibility(contentToToggle, for: .schematic)
        document.scheduleAutosave()
    }
    
    func updateText(for component: ComponentInstance, with editedText: CircuitText.Resolved) {
        // This is a visual-only change.
     /*   component.apply(editedText, for: selectedEditor)*/ // Assuming this helper exists
        document.scheduleAutosave()
    }

    func addText(_ newText: CircuitText.Instance, to component: ComponentInstance) {
        // This is a visual-only change.
//        component.add(newText, for: selectedEditor) // Assuming this helper exists
        document.scheduleAutosave()
    }

    func removeText(_ textToRemove: CircuitText.Resolved, from component: ComponentInstance) {
        // This is a visual-only change.
        /*component.remove(textToRemove, for: selectedEditor)*/ // Assuming this helper exists
        document.scheduleAutosave()
    }
    
    func updateReferenceDesignator(for component: ComponentInstance, newIndex: Int, sessionID: UUID? = nil) {
        switch syncManager.syncMode {
        case .automatic:
            component.referenceDesignatorIndex = newIndex
            document.scheduleAutosave()
        case .manualECO:
            let oldIndex = syncManager.resolvedReferenceDesignator(for: component, onlyFrom: selectedEditor.changeSource)
            guard newIndex != oldIndex else { return }
            let payload = ChangeType.updateReferenceDesignator(componentID: component.id, newIndex: newIndex, oldIndex: oldIndex)
            syncManager.recordChange(source: selectedEditor.changeSource, payload: payload, sessionID: sessionID)
        }
    }
    
    func assignFootprint(to component: ComponentInstance, footprint: FootprintDefinition?, sessionID: UUID? = nil) {
        switch syncManager.syncMode {
        case .automatic:
            if let footprint = footprint {
                let oldPlacement = component.footprintInstance?.placement ?? .unplaced
                let oldPosition = component.footprintInstance?.position ?? .zero
                let oldRotation = component.footprintInstance?.rotation ?? 0
                
                let newFootprintInstance = FootprintInstance(
                    definitionUUID: footprint.uuid,
                    definition: footprint,
                    placement: oldPlacement
                )
                newFootprintInstance.position = oldPosition
                newFootprintInstance.rotation = oldRotation
                component.footprintInstance = newFootprintInstance
            } else {
                component.footprintInstance = nil
            }
            document.scheduleAutosave()
        case .manualECO:
            let oldName = syncManager.resolvedFootprintName(for: component, onlyFrom: selectedEditor.changeSource)
            let payload = ChangeType.assignFootprint(componentID: component.id, newFootprintUUID: footprint?.uuid, newFootprintName: footprint?.name, oldFootprintName: oldName)
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
                document.scheduleAutosave()
            }
        case .manualECO:
            // TODO: Requires a new ChangeType case, e.g., `.updatePlacement(...)`
            print("MANUAL ECO: Place component action not yet implemented.")
        }
    }
    
    // MARK: - String Generation (Shared Utility)
    
    /// Generates the display string for a given text model. It uses the SyncManager's resolvers
    /// to ensure it correctly displays pending values when in Manual ECO mode.
    func generateString(for resolvedText: CircuitText.Resolved, component: ComponentInstance) -> String {
        let overlaySource: ChangeSource? = (selectedEditor == .schematic && syncManager.syncMode == .manualECO) ? .schematic : nil

        switch resolvedText.content {
        case .static(let text):
            return text
        case .componentName:
            return component.definition?.name ?? "???"
        case .componentReferenceDesignator:
            let idx = syncManager.resolvedReferenceDesignator(for: component, onlyFrom: overlaySource)
            return (component.definition?.referenceDesignatorPrefix ?? "REF?") + String(idx)
        case .componentProperty(let definitionID, let options):
            guard let prop = syncManager.resolvedProperty(for: component, propertyID: definitionID, onlyFrom: overlaySource) else { return "" }
            var parts: [String] = []
            if options.showKey { parts.append(prop.key.label) }
            if options.showValue { parts.append(prop.value.description) }
            if options.showUnit, !prop.unit.description.isEmpty { parts.append(prop.unit.description) }
            return parts.joined(separator: " ")
        }
    }
}
