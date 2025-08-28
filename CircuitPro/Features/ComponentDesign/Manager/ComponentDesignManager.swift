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

    var draftProperties: [DraftProperty] = [DraftProperty(key: nil, value: .single(nil), unit: .init())] {
        didSet {
            let validProperties = componentProperties
            symbolEditor.synchronizeSymbolTextWithProperties(properties: validProperties)
            footprintEditor.synchronizeSymbolTextWithProperties(properties: validProperties)
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

    /// A computed property providing a list of available semantic text sources.
    /// This now uses the simplified `TextSource` enum.
    var availableTextSources: [(displayName: String, source: TextSource)] {
        var sources: [(String, TextSource)] = []
        
        if !componentName.isEmpty {
            sources.append(("Name", .componentName))
        }
        if !referenceDesignatorPrefix.isEmpty {
            sources.append(("Reference", .reference))
        }
        for propDef in componentProperties {
            sources.append((propDef.key.label, .property(definitionID: propDef.id)))
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
        draftProperties = [DraftProperty(key: nil, value: .single(nil), unit: .init())]
        
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
