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

    var componentName: String = "" { didSet { refreshValidation() } }
    var componentAbbreviation: String = "" { didSet { refreshValidation() } }
    var selectedCategory: ComponentCategory? { didSet { refreshValidation() } }
    var selectedPackageType: PackageType?
    var componentProperties: [ComponentProperty] = [ComponentProperty(key: nil, value: .single(nil), unit: .init())] { didSet { refreshValidation() } }

    // MARK: - Validation
    var validationSummary = ValidationSummary()
    var showFieldErrors = false

    // MARK: - Symbol
    var symbolElements: [CanvasElement] = [] {
        didSet {
            updateSymbolIndexMap()
            refreshValidation()
        }
    }
    var selectedSymbolElementIDs: Set<UUID> = []
    var selectedSymbolTool: AnyCanvasTool = AnyCanvasTool(CursorTool())
    private var symbolElementIndexMap: [UUID: Int] = [:]

    // MARK: - Footprint
    var footprintElements: [CanvasElement] = [] {
        didSet {
            updateFootprintIndexMap()
            refreshValidation()
        }
    }
    var selectedFootprintElementIDs: Set<UUID> = []
    var selectedFootprintTool: AnyCanvasTool = AnyCanvasTool(CursorTool())
    private var footprintElementIndexMap: [UUID: Int] = [:]

    var selectedFootprintLayer: CanvasLayer? = .layer0
    var layerAssignments: [UUID: CanvasLayer] = [:]

    private func updateSymbolIndexMap() {
        symbolElementIndexMap = Dictionary(
            uniqueKeysWithValues: symbolElements.enumerated().map { ($1.id, $0) }
        )
    }

    private func updateFootprintIndexMap() {
        footprintElementIndexMap = Dictionary(
            uniqueKeysWithValues: footprintElements.enumerated().map { ($1.id, $0) }
        )
    }

    // MARK: - Reset All State
    func resetAll() {
        // 1. Component metadata
        componentName = ""
        componentAbbreviation = ""
        selectedCategory = nil
        selectedPackageType = nil
        componentProperties = [
            ComponentProperty(key: nil, value: .single(nil), unit: .init())
        ]

        // 2. Symbol design
        symbolElements = []
        selectedSymbolElementIDs = []
        selectedSymbolTool = AnyCanvasTool(CursorTool())

        // 3. Footprint design
        footprintElements = []
        selectedFootprintElementIDs = []
        selectedFootprintTool = AnyCanvasTool(CursorTool())
        selectedFootprintLayer = .layer0
        layerAssignments = [:]

        // 4. Validation
        validationSummary = ValidationSummary()
        showFieldErrors = false
    }

    func refreshValidation() {
        guard showFieldErrors else { return }
        validationSummary = validate()
    }

    @discardableResult
    func validateForCreation() -> Bool {
        validationSummary = validate()
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

    func validate() -> ValidationSummary {
        var summary = ValidationSummary()

        for stage in ComponentDesignStage.allCases {
            let stageResult = stage.validate(manager: self)

            if !stageResult.errors.isEmpty {
                summary.errors[stage] = stageResult.errors
            }

            if !stageResult.warnings.isEmpty {
                summary.warnings[stage] = stageResult.warnings
            }
        }

        return summary
    }
}

extension ComponentDesignManager {
    var pins: [Pin] {
        symbolElements.compactMap {
            if case .pin(let pin) = $0 {
                return pin
            }
            return nil
        }
    }

    var selectedPins: [Pin] {
        symbolElements.compactMap {
            if case .pin(let pin) = $0, selectedSymbolElementIDs.contains(pin.id) {
                return pin
            }
            return nil
        }
    }

    func bindingForPin(with id: UUID) -> Binding<Pin>? {
        guard let index = symbolElementIndexMap[id],
              case .pin(let pin) = symbolElements[safe: index]
        else {
            return nil
        }

        return Binding<Pin>(
            get: {
                guard let index = self.symbolElementIndexMap[id],
                      case .pin(let p) = self.symbolElements[safe: index]
                else { return pin }
                return p
            },
            set: { newValue in
                if let index = self.symbolElementIndexMap[id],
                   self.symbolElements.indices.contains(index)
                {
                    self.symbolElements[index] = .pin(newValue)
                }
            }
        )
    }
}

extension ComponentDesignManager {
    var pads: [Pad] {
        footprintElements.compactMap {
            if case .pad(let pad) = $0 {
                return pad
            }
            return nil
        }
    }

    var selectedPads: [Pad] {
        footprintElements.compactMap {
            if case .pad(let pad) = $0, selectedFootprintElementIDs.contains(pad.id) {
                return pad
            }
            return nil
        }
    }

    func bindingForPad(with id: UUID) -> Binding<Pad>? {
        guard let index = footprintElementIndexMap[id],
              case .pad(let pad) = footprintElements[safe: index]
        else {
            return nil
        }

        return Binding<Pad>(
            get: {
                guard let index = self.footprintElementIndexMap[id],
                      case .pad(let p) = self.footprintElements[safe: index]
                else { return pad }
                return p
            },
            set: { newValue in
                if let index = self.footprintElementIndexMap[id],
                   self.footprintElements.indices.contains(index)
                {
                    self.footprintElements[index] = .pad(newValue)
                }
            }
        )
    }
}
