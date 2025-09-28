import SwiftUI
import Observation

// MARK: - Schematic render helper (used by SchematicNodeProvider)
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
    
    /// Convenience accessor for the underlying data model.
    var project: CircuitProject { document.model }
    
    var syncManager: SyncManager { document.syncManager }
    
    /// The currently active design within the project.
    var selectedDesign: CircuitDesign?

    // MARK: - Editor Controllers
    
    /// The dedicated controller for the schematic editor. It manages all schematic-specific view state.
    @ObservationIgnored
    lazy var schematicController: SchematicEditorController = {
        SchematicEditorController(projectManager: self)
    }()
    
    @ObservationIgnored
    lazy var layoutController: LayoutEditorController = {
        LayoutEditorController(projectManager: self)
    }()
    
    // MARK: - Global UI State
    
    var selectedNodeIDs: Set<UUID> = []
    var selectedNetIDs: Set<UUID> = []
    var selectedEditor: EditorType = .schematic
    
    /// Nodes for the currently active editor.
    var activeCanvasNodes: [BaseNode] {
        switch selectedEditor {
        case .schematic: return schematicController.nodes
        case .layout:    return layoutController.nodes
        }
    }
    
    /// Controller for the active editor (used e.g. by Inspector).
    var activeEditorController: EditorController? {
        switch selectedEditor {
        case .schematic: return schematicController
        case .layout:    return layoutController
        }
    }

    // MARK: - Init

    init(document: CircuitProjectFileDocument, selectedDesign: CircuitDesign? = nil) {
        self.document = document
        self.selectedDesign = selectedDesign ?? document.model.designs.first
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
            guard let oldResolved = oldResolved,
                  editedProperty.value != oldResolved.value || editedProperty.unit != oldResolved.unit
            else { return }
            let payload = ChangeType.updateProperty(
                componentID: component.id,
                newProperty: editedProperty,
                oldProperty: oldResolved
            )
            syncManager.recordChange(source: selectedEditor.changeSource, payload: payload, sessionID: sessionID)
        }
    }
    
    func applyChanges(_ records: [ChangeRecord], allFootprints: [FootprintDefinition]) {
        for record in records.reversed() {
            guard let component = componentInstances.first(where: { $0.id == record.payload.componentID }) else { continue }
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
            // TODO: Implement ChangeType.addProperty
            print("MANUAL ECO: Add property action not yet implemented.")
        }
    }
    
    func removeProperty(_ propertyToRemove: Property.Resolved, from component: ComponentInstance) {
        switch syncManager.syncMode {
        case .automatic:
            component.remove(propertyToRemove)
            document.scheduleAutosave()
        case .manualECO:
            // TODO: Implement ChangeType.removeProperty
            print("MANUAL ECO: Remove property action not yet implemented.")
        }
    }

    // MARK: - TEXT VISIBILITY / TEXT EDITS (schematic + layout)

    /// Toggle visibility of a dynamic text item (name, refdes, property text, etc.)
    /// Routes to Symbol (schematic) or Footprint (layout) based on the active editor.
    func toggleDynamicTextVisibility(for component: ComponentInstance, content: CircuitTextContent) {
        switch selectedEditor {
        case .schematic:
            // Symbol text
            if var resolved = component.symbolInstance.resolvedItems.first(where: { $0.content.isSameType(as: content) }) {
                resolved.isVisible.toggle()
                component.symbolInstance.apply(resolved)
            }
        case .layout:
            // Footprint text
            if let fp = component.footprintInstance,
               var resolved = fp.resolvedItems.first(where: { $0.content.isSameType(as: content) }) {
                resolved.isVisible.toggle()
                fp.apply(resolved)
            }
        }
        document.scheduleAutosave()
    }
    
    /// Toggle visibility for a specific **property** text on the **symbol** (schematic only concept).
    func togglePropertyVisibility(for component: ComponentInstance, property: Property.Resolved) {
        guard case .definition(let propertyDef) = property.source else { return }
        // Get the default options defined on the symbol (used to build the content key).
        let defaultOptions = component.definition?.symbol?.textDefinitions
            .first(where: { $0.content.isSameType(as: .componentProperty(definitionID: propertyDef.id, options: .default)) })?
            .content.displayOptions ?? .default
        
        let contentToToggle = CircuitTextContent.componentProperty(definitionID: propertyDef.id, options: defaultOptions)
        
        // Always operate on the symbol for property visibility (schematic concept).
        if var resolved = component.symbolInstance.resolvedItems.first(where: { $0.content.isSameType(as: contentToToggle) }) {
            resolved.isVisible.toggle()
            component.symbolInstance.apply(resolved)
            document.scheduleAutosave()
        }
    }
    
    /// Apply a full edit to a resolved text item (e.g., changing display options).
    func updateText(for component: ComponentInstance, with editedText: CircuitText.Resolved) {
        switch selectedEditor {
        case .schematic:
            component.symbolInstance.apply(editedText)
        case .layout:
            component.footprintInstance?.apply(editedText)
        }
        document.scheduleAutosave()
    }
    
    // MARK: - Reference Designator

    func updateReferenceDesignator(
        for component: ComponentInstance,
        newIndex: Int,
        sessionID: UUID? = nil
    ) {
        switch syncManager.syncMode {
        case .automatic:
            component.referenceDesignatorIndex = newIndex
            document.scheduleAutosave()

        case .manualECO:
            let oldIndex = syncManager.resolvedReferenceDesignator(
                for: component,
                onlyFrom: selectedEditor.changeSource
            )
            guard newIndex != oldIndex else { return }
            let payload = ChangeType.updateReferenceDesignator(
                componentID: component.id,
                newIndex: newIndex,
                oldIndex: oldIndex
            )
            syncManager.recordChange(
                source: selectedEditor.changeSource,
                payload: payload,
                sessionID: sessionID
            )
        }
    }


    /// Add a new ad-hoc text instance to the active container.
    func addText(_ newText: CircuitText.Instance, to component: ComponentInstance) {
        switch selectedEditor {
        case .schematic:
            component.symbolInstance.add(newText)
        case .layout:
            component.footprintInstance?.add(newText)
        }
        document.scheduleAutosave()
    }

    /// Remove a text item from the active container.
    func removeText(_ textToRemove: CircuitText.Resolved, from component: ComponentInstance) {
        switch selectedEditor {
        case .schematic:
            component.symbolInstance.remove(textToRemove)
        case .layout:
            component.footprintInstance?.remove(textToRemove)
        }
        document.scheduleAutosave()
    }
    
    // MARK: - Layout placement
    
    func assignFootprint(to component: ComponentInstance, footprint: FootprintDefinition?, sessionID: UUID? = nil) {
        switch syncManager.syncMode {
        case .automatic:
            if let footprint = footprint {
                let oldPlacement = component.footprintInstance?.placement ?? .unplaced
                let oldPosition  = component.footprintInstance?.position  ?? .zero
                let oldRotation  = component.footprintInstance?.rotation  ?? 0
                
                let newFootprintInstance = FootprintInstance(
                    definitionUUID: footprint.uuid,
                    definition: footprint,
                    position: oldPosition,
                    cardinalRotation: .closest(to: oldRotation),
                    placement: oldPlacement
                )
                component.footprintInstance = newFootprintInstance
            } else {
                component.footprintInstance = nil
            }
            document.scheduleAutosave()
        case .manualECO:
            let oldName = syncManager.resolvedFootprintName(for: component, onlyFrom: selectedEditor.changeSource)
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
                document.scheduleAutosave()
            }
        case .manualECO:
            // TODO: ChangeType.updatePlacement(...)
            print("MANUAL ECO: Place component action not yet implemented.")
        }
    }
    
    // MARK: - String Generation (Shared Utility)
    
    /// Generates the display string for a given text model. Uses the SyncManager's resolvers
    /// to overlay pending values when in Manual ECO mode.
    func generateString(for resolvedText: CircuitText.Resolved, component: ComponentInstance) -> String {
        let overlaySource: ChangeSource? =
            (selectedEditor == .schematic && syncManager.syncMode == .manualECO) ? .schematic : nil

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
            if options.showKey   { parts.append(prop.key.label) }
            if options.showValue { parts.append(prop.value.description) }
            if options.showUnit, !prop.unit.description.isEmpty { parts.append(prop.unit.description) }
            return parts.joined(separator: " ")
        }
    }
}
