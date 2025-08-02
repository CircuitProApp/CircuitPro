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
        didSet {
            didUpdateComponentData()
        }
    }
    var referenceDesignatorPrefix: String = "" {
        didSet {
            didUpdateComponentData()
        }
    }
    var selectedCategory: ComponentCategory? {
        didSet {
            refreshValidation()
        }
    }
    var selectedPackageType: PackageType?

    var componentProperties: [PropertyDefinition] = [PropertyDefinition(key: nil, defaultValue: .single(nil), unit: .init())] {
        didSet {
            symbolEditor.synchronizeSymbolTextWithProperties(properties: componentProperties)
            footprintEditor.synchronizeSymbolTextWithProperties(properties: componentProperties)
            didUpdateComponentData()
        }
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
        selectedPackageType = nil
        componentProperties = [PropertyDefinition(key: nil, defaultValue: .single(nil), unit: .init())]
        
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