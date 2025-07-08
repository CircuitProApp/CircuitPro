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

    var componentName: String = ""
    var componentAbbreviation: String = ""
    var selectedCategory: ComponentCategory?
    var selectedPackageType: PackageType?
    var componentProperties: [ComponentProperty] = [ComponentProperty(key: nil, value: .single(nil), unit: .init())]

    // MARK: - Symbol
    var symbolElements: [CanvasElement] = []
    var selectedSymbolElementIDs: Set<UUID> = []
    var selectedSymbolTool: AnyCanvasTool = AnyCanvasTool(CursorTool())

    // MARK: - Footprint
    var footprintElements: [CanvasElement] = []
    var selectedFootprintElementIDs: Set<UUID> = []
    var selectedFootprintTool: AnyCanvasTool = AnyCanvasTool(CursorTool())

    var selectedFootprintLayer: CanvasLayer? = .layer0
    var layerAssignments: [UUID: CanvasLayer] = [:]

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
    }

    func validate() -> ValidationResult {
        var errors   = [String]()
        var warnings = [String]()

        // 1. Errors on missing core fields
        if componentName.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("Component must have a name.")
        }
        if componentAbbreviation.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("Component must have an abbreviation.")
        }
        if selectedCategory == nil {
            errors.append("Component must have a category.")
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
            errors.append("No symbol created.")
        }
        if pins.isEmpty {
            errors.append("No pins added to symbol.")
        }

        // 3. Warning if no property has a key
        let hasAnyKey = componentProperties.contains { $0.key != nil }
        if !hasAnyKey {
            warnings.append("At least one property should have a key.")
        }

        return ValidationResult(errors: errors, warnings: warnings)
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
        guard let index = symbolElements.firstIndex(where: {
            if case .pin(let pin) = $0 { return pin.id == id }
            return false
        }) else {
            return nil
        }

        guard case .pin = symbolElements[index] else {
            return nil
        }

        return Binding<Pin>(
            get: {
                if case .pin(let pin) = self.symbolElements[safe: index] {
                    return pin
                } else {
                    return Pin(name: "T", number: 0, position: .zero, type: .unknown) // fallback (or throw)
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
        guard let index = footprintElements.firstIndex(where: {
            if case .pad(let pad) = $0 { return pad.id == id }
            return false
        }) else {
            return nil
        }

        guard case .pad = footprintElements[safe: index] else {
            return nil
        }

        return Binding<Pad>(
            get: {
                if case .pad(let pad) = self.footprintElements[safe: index] {
                    return pad
                } else {
                    return Pad(number: 0, position: .zero) // fallback default or handle as needed
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

// MARK: - Which fields can have errors
struct ValidationSummary {
    var errors:   [ComponentField : String] = [:]     // blocking
    var warnings: [ComponentField : String] = [:]     // non-blocking
    var isValid:  Bool { errors.isEmpty }             // only errors block
}

enum ComponentField: Hashable {
    case name, abbreviation, category, packageType, properties
}

extension ComponentDesignManager {
    func validateDetails() -> ValidationSummary {
        var summary = ValidationSummary()

        if componentName.trimmingCharacters(in: .whitespaces).isEmpty {
            summary.errors[.name] = "Component name is required."
        }
        if componentAbbreviation.trimmingCharacters(in: .whitespaces).isEmpty {
            summary.errors[.abbreviation] = "Abbreviation is required."
        }
        if selectedCategory == nil {
            summary.errors[.category] = "Choose a category."
        }
        if selectedPackageType == nil {
            summary.errors[.packageType] = "Choose a package type."
        }

        // NEW –– property-key rule → *warning*
        let hasAnyKey = componentProperties.contains { $0.key != nil }
        if !hasAnyKey {
            summary.warnings[.properties] =
              "At least one property should have a key."
        }
        return summary
    }
}
