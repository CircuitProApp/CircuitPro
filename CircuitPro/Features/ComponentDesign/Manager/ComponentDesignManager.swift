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
    let footprintEditor = CanvasEditorManager()

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

    /// The internal state for properties being edited in the UI.
    /// This now uses the new `DraftProperty` model.
    var draftProperties: [DraftProperty] = [DraftProperty(key: nil, value: .single(nil), unit: .init())] { // <-- Updated type and value
        didSet {
            let validProperties = componentProperties
            symbolEditor.synchronizeSymbolTextWithProperties(properties: validProperties)
            footprintEditor.synchronizeSymbolTextWithProperties(properties: validProperties)
            didUpdateComponentData()
        }
    }
    
    /// A computed property that returns only the valid, non-optional `Property.Definition`s.
    /// This is the canonical data that should be used for saving the component.
    var componentProperties: [Property.Definition] { // <-- Updated return type
        draftProperties.compactMap { draft in
            guard let key = draft.key else { return nil }
            // Creates the macro-generated `Property.Definition` struct.
            return Property.Definition( // <-- Updated to use macro-generated type
                id: draft.id,
                key: key,
                value: draft.value, unit: draft.unit,
                warnsOnEdit: draft.warnsOnEdit // <-- Field name updated from 'defaultValue'
            )
        }
    }

    /// A computed property providing a list of text sources.
    /// No changes are needed here, as `Property.Definition` still has `key` and `id`.
    var availableTextSources: [(displayName: String, source: TextSource)] {
        var sources: [(String, TextSource)] = []
        if !componentName.isEmpty { sources.append(("Name", .dynamic(.componentName))) }
        if !referenceDesignatorPrefix.isEmpty { sources.append(("Reference", .dynamic(.reference))) }
        for propDef in componentProperties {
            sources.append((propDef.key.label, .dynamic(.property(definitionID: propDef.id))))
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
        footprintEditor.updateDynamicTextElements(componentData: data)
        refreshValidation()
    }

    // MARK: - Public Methods
    func resetAll() {
        componentName = ""
        referenceDesignatorPrefix = ""
        selectedCategory = nil
        // Reset with the new `DraftProperty` struct
        draftProperties = [DraftProperty(key: nil, value: .single(nil), unit: .init())] // <-- Updated type and value
        
        symbolEditor.reset()
        footprintEditor.reset()
        
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
