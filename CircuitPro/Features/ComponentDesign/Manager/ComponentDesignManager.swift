//
//  ComponentDesignManager.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/19/25.
//

import SwiftUI
import Observation

@Observable
final class ComponentDesignManager {

    // MARK: - Child Managers
    let symbolEditor = CanvasEditorManager()
    
    // --- NEW ARCHITECTURE ---
    
    /// Holds the work-in-progress drafts for each new footprint.
    /// Each draft is a self-contained object holding its name and its dedicated editor (UI state).
    var footprintDrafts: [FootprintDraft] = []
    
    /// Holds footprints that will be linked from an existing library (pre-existing models).
    var assignedFootprints: [FootprintDefinition] = []
    
    /// The ID of the currently selected footprint draft. This is the source of truth for navigation.
    /// If this is non-nil, the UI should show the canvas editor. If nil, it should show the Hub.
    var selectedFootprintID: UUID?
    
    var currentStage: ComponentDesignStage = .details
    
    /// A computed property to easily access the currently selected draft object and its associated editor.
    var selectedFootprintDraft: FootprintDraft? {
        guard let selectedFootprintID else { return nil }
        return footprintDrafts.first(where: { $0.id == selectedFootprintID })
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
            footprintDrafts.forEach { $0.editor.synchronizeSymbolTextWithProperties(properties: validProperties) }
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
        footprintDrafts.forEach { $0.editor.updateDynamicTextElements(componentData: data) }
        refreshValidation()
    }

    // MARK: - Public Methods
    
    /// Creates a new footprint draft, which encapsulates its own name and editor state.
    func addNewFootprint() {
        let newDraft = FootprintDraft(name: "Footprint \(footprintDrafts.count + 1)")
        footprintDrafts.append(newDraft)
        // We do NOT automatically select it. The user must click "Open" from the Hub.
    }
    
    /// Resets the entire component design session to its initial state.
    func resetAll() {
        componentName = ""
        referenceDesignatorPrefix = ""
        selectedCategory = nil
        draftProperties = [DraftProperty(key: nil, value: .single(nil), unit: .init())]
        
        symbolEditor.reset()
        footprintDrafts.removeAll()
        assignedFootprints.removeAll()
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
