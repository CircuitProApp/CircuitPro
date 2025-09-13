//
//  ComponentDesignManager.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/19/25.
//

import SwiftUI
import Observation

// The temporary `Footprint` class has been removed entirely.

@Observable
final class ComponentDesignManager {

    // MARK: - Child Managers
    let symbolEditor = CanvasEditorManager()
    
    // --- NEW ARCHITECTURE ---
    
    /// Holds the drafts of the actual @Model object. These are temporary until the component is saved.
    var newFootprints: [FootprintDefinition] = []
    
    /// Holds the temporary UI state (the editor) for each draft, mapping the draft's UUID to its editor.
    /// This keeps the UI state completely separate from the data model.
    var footprintEditors = [UUID: CanvasEditorManager]()
    
    /// Holds footprints that will be linked from an existing library.
    var assignedFootprints: [FootprintDefinition] = []
    
    /// The UUID of the currently selected footprint draft.
    var selectedFootprintID: UUID?
    
    var navigationPath: NavigationPath = .init()
    
    /// The currently selected footprint draft model.
    var selectedFootprint: FootprintDefinition? {
        guard let selectedFootprintID else { return nil }
        return newFootprints.first(where: { $0.uuid == selectedFootprintID })
    }
    
    /// The canvas editor for the currently selected footprint draft.
    var selectedFootprintEditor: CanvasEditorManager? {
        guard let selectedFootprintID else { return nil }
        return footprintEditors[selectedFootprintID]
    }

    // MARK: - Component Metadata
    var componentName: String = "" {
        didSet { didUpdateComponentData() }
    }
    var referenceDesignatorPrefix: String = "" {
        didSet { didUpdateComponentData() }
    }
    var selectedCategory: ComponentCategory? {
        didSet { refreshValidation() }
    }

    var draftProperties: [DraftProperty] = [DraftProperty(key: nil, value: .single(nil), unit: .init())] {
        didSet {
            let validProperties = componentProperties
            symbolEditor.synchronizeSymbolTextWithProperties(properties: validProperties)
            footprintEditors.values.forEach { $0.synchronizeSymbolTextWithProperties(properties: validProperties) }
            didUpdateComponentData()
        }
    }
    
    var componentProperties: [Property.Definition] {
        draftProperties.compactMap { draft in
            guard let key = draft.key else { return nil }
            return Property.Definition(
                id: draft.id,
                key: key,
                value: draft.value, unit: draft.unit,
                warnsOnEdit: draft.warnsOnEdit
            )
        }
    }

    var availableTextSources: [(displayName: String, source: CircuitTextContent)] {
        var sources: [(String, CircuitTextContent)] = []
        
        if !componentName.isEmpty {
            sources.append(("Name", .componentName))
        }
        if !referenceDesignatorPrefix.isEmpty {
            sources.append(("Reference", .componentReferenceDesignator))
        }
        
        for propDef in componentProperties {
            sources.append((propDef.key.label, .componentProperty(definitionID: propDef.id, options: .default)))
        }
        
        return sources
    }

    // MARK: - Validation State
    var validationSummary = ValidationSummary()
    var showFieldErrors = false
    
    private var validator: ComponentValidator {
        ComponentValidator(manager: self)
    }

    // MARK: - Initializer
    init() {}

    // MARK: - Orchestration
    private func didUpdateComponentData() {
        let data = (componentName, referenceDesignatorPrefix, componentProperties)
        symbolEditor.updateDynamicTextElements(componentData: data)
        footprintEditors.values.forEach { $0.updateDynamicTextElements(componentData: data) }
        refreshValidation()
    }

    // MARK: - Public Methods
    
    /// Creates a new footprint model draft and a corresponding temporary editor for it.
    func addNewFootprint() {
        // 1. Create a new instance of the actual data model.
        let newFootprint = FootprintDefinition(
            name: "Footprint \(newFootprints.count + 1)",
            primitives: [] // Starts empty
        )
        newFootprints.append(newFootprint)
        
        // 2. Create a temporary editor for it and store it in our dictionary.
        let newEditor = CanvasEditorManager()
        newEditor.setupForFootprintEditing()
        footprintEditors[newFootprint.uuid] = newEditor
    }
    
    /// Resets the entire component design session to its initial state.
    func resetAll() {
        componentName = ""
        referenceDesignatorPrefix = ""
        selectedCategory = nil
        draftProperties = [DraftProperty(key: nil, value: .single(nil), unit: .init())]
        
        symbolEditor.reset()
        newFootprints.removeAll()
        assignedFootprints.removeAll()
        footprintEditors.removeAll() // Clear the temporary editors
        selectedFootprintID = nil
        
        validationSummary = ValidationSummary()
        showFieldErrors = false
    }
}

// MARK: - Validation
extension ComponentDesignManager {
    func refreshValidation() {
        guard showFieldErrors else { return }
        validationSummary = validator.validate()
    }

    @discardableResult
    func validateForCreation() -> Bool {
        validationSummary = validator.validate()
        showFieldErrors = true
        return validationSummary.isValid
    }

    func validationState(for requirement: any StageRequirement) -> ValidationState {
        guard showFieldErrors else { return .valid }
        let key = AnyHashable(requirement)
        var state: ValidationState = .valid
        if validationSummary.requirementErrors[key] != nil {
            state.insert(.error)
        }
        if validationSummary.requirementWarnings[key] != nil {
            state.insert(.warning)
        }
        return state
    }

    func validationState(for stage: ComponentDesignStage) -> ValidationState {
        guard showFieldErrors else { return .valid }
        var state: ValidationState = .valid
        if !(validationSummary.errors[stage]?.isEmpty ?? true) {
            state.insert(.error)
        }
        if !(validationSummary.warnings[stage]?.isEmpty ?? true) {
            state.insert(.warning)
        }
        return state
    }
}
