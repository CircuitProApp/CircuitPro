//
//  ComponentDesignManager.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/19/25.
//

import SwiftUI
import Observation

struct ValidationSummary {
    var errors:   [ComponentField : String] = [:]
    var warnings: [ComponentField : String] = [:]
    var isValid:  Bool { errors.isEmpty }
}

enum ComponentField: Hashable {
    case name, abbreviation, category, properties, symbol, pins
}

@Observable
final class ComponentDesignManager {

    var componentName: String = ""
    var componentAbbreviation: String = ""
    var selectedCategory: ComponentCategory?
    var selectedPackageType: PackageType?
    var componentProperties: [ComponentProperty] = [ComponentProperty(key: nil, value: .single(nil), unit: .init())]

    // MARK: - Validation
    var validationSummary = ValidationSummary()
    var showFieldErrors = false

    // MARK: - Symbol
    var symbolElements: [CanvasElement] = [] {
        didSet {
            updateSymbolIndexMap()
        }
    }
    var selectedSymbolElementIDs: Set<UUID> = []
    var selectedSymbolTool: AnyCanvasTool = AnyCanvasTool(CursorTool())
    private var symbolElementIndexMap: [UUID: Int] = [:]

    // MARK: - Footprint
    var footprintElements: [CanvasElement] = [] {
        didSet {
            updateFootprintIndexMap()
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

    func validate() -> ValidationSummary {
        var summary = ValidationSummary()

        // 1. Errors on missing core fields
        if componentName.trimmingCharacters(in: .whitespaces).isEmpty {
            summary.errors[.name] = "Component name is required."
        }
        if componentAbbreviation.trimmingCharacters(in: .whitespaces).isEmpty {
            summary.errors[.abbreviation] = "Abbreviation is required."
        }
        if selectedCategory == nil {
            summary.errors[.category] = "Choose a category."
        }

        // 2. Errors on symbol/primitives & pins
        let primitives = symbolElements.compactMap { elem -> AnyPrimitive? in
            if case .primitive(let primitive) = elem { return primitive }
            return nil
        }
        let pins = symbolElements.compactMap { elem -> Pin? in
            if case .pin(let pin) = elem { return pin }
            return nil
        }

        if primitives.isEmpty {
            summary.errors[.symbol] = "No symbol created."
        }
        if pins.isEmpty {
            summary.errors[.pins] = "No pins added to symbol."
        }

        // 3. Warning if no property has a key
        let hasAnyKey = componentProperties.contains { $0.key != nil }
        if !hasAnyKey {
            summary.errors[.properties] = "At least one property should have a key."
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
              case .pin = symbolElements[safe: index]
        else {
            return nil
        }

        return Binding<Pin>(
            get: {
                if case .pin(let pin) = self.symbolElements[safe: index] {
                    return pin
                } else {
                    fatalError("Index map is out of sync or element is not a Pin.")
                }
            },
            set: { newValue in
                if self.symbolElements.indices.contains(index) {
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
              case .pad = footprintElements[safe: index]
        else {
            return nil
        }

        return Binding<Pad>(
            get: {
                if case .pad(let pad) = self.footprintElements[safe: index] {
                    return pad
                } else {
                    fatalError("Index map is out of sync or element is not a Pad.")
                }
            },
            set: { newValue in
                if self.footprintElements.indices.contains(index) {
                    self.footprintElements[index] = .pad(newValue)
                }
            }
        )
    }
}
