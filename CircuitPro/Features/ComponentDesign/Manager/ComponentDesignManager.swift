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
    var componentAbbreviation: String = "" {
        didSet {
            updateAbbreviationTextElement()
            refreshValidation()
        }
    }
    var selectedCategory: ComponentCategory? { didSet { refreshValidation() } }
    var selectedPackageType: PackageType?
    var componentProperties: [PropertyDefinition] = [PropertyDefinition(key: nil, defaultValue: .single(nil), unit: .init())] { didSet { refreshValidation() } }

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
    private(set) var abbreviationTextElementID: UUID?

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
    
    // MARK: Abbreviation Text Element Handling
    private func updateAbbreviationTextElement() {
        // 1. Check if an abbreviation text element already exists.
        if let elementID = abbreviationTextElementID,
           let index = symbolElementIndexMap[elementID] {
            
            // If the new abbreviation is empty, remove the element.
            if componentAbbreviation.isEmpty {
                symbolElements.remove(at: index)
                abbreviationTextElementID = nil
                return
            }

            // Otherwise, update the existing element's text.
            guard case .text(var textElement) = symbolElements[index] else {
                // This case should ideally not happen if our ID logic is correct.
                // We'll reset the ID and create a new element to be safe.
                abbreviationTextElementID = nil
                if !componentAbbreviation.isEmpty { createAbbreviationTextElement() }
                return
            }
            
            textElement.text = componentAbbreviation
            symbolElements[index] = .text(textElement)

        } else if !componentAbbreviation.isEmpty {
            // 2. If no element exists and the abbreviation is not empty, create one.
            createAbbreviationTextElement()
        }
    }

    private func createAbbreviationTextElement() {
        // 1. By default, the symbol canvas uses A4 paper in landscape.
        let defaultPaper = PaperSize.iso(.a4)
        let canvasSize = defaultPaper.canvasSize(orientation: .landscape)

        // 2. Calculate the center point of this default canvas.
        let centerPoint = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)

        // 3. Create the text element at the center.
        let newElement = TextElement(
            id: UUID(),
            text: componentAbbreviation,
            position: centerPoint
        )
        abbreviationTextElementID = newElement.id
        symbolElements.append(.text(newElement))
    }

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
            PropertyDefinition(key: nil, defaultValue: .single(nil), unit: .init())
        ]

        // 2. Symbol design
        symbolElements = []
        selectedSymbolElementIDs = []
        selectedSymbolTool = AnyCanvasTool(CursorTool())
        abbreviationTextElementID = nil // Reset the tracked ID

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
                      case .pin(let currentPin) = self.symbolElements[safe: index]
                else { return pin }
                return currentPin
            },
            set: { newValue in
                if let index = self.symbolElementIndexMap[id],
                   self.symbolElements.indices.contains(index) {
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
                      case .pad(let currentPad) = self.footprintElements[safe: index]
                else { return pad }
                return currentPad
            },
            set: { newValue in
                if let index = self.footprintElementIndexMap[id],
                   self.footprintElements.indices.contains(index) {
                    self.footprintElements[index] = .pad(newValue)
                }
            }
        )
    }
}

// MARK: - Symbol primitives
extension ComponentDesignManager {
    var symbolPrimitives: [AnyPrimitive] {
        symbolElements.compactMap {
            if case .primitive(let prim) = $0 { return prim }
            return nil
        }
    }

    var selectedSymbolPrimitives: [AnyPrimitive] {
        symbolElements.compactMap {
            if case .primitive(let prim) = $0,
               selectedSymbolElementIDs.contains(prim.id) { return prim }
            return nil
        }
    }

    func bindingForPrimitive(with id: UUID) -> Binding<AnyPrimitive>? {
        guard let index = symbolElementIndexMap[id],
              case .primitive(let prim) = symbolElements[safe: index] else { return nil }

        return Binding(
            get: {
                guard let idx = self.symbolElementIndexMap[id],
                      case .primitive(let p) = self.symbolElements[safe: idx] else { return prim }
                return p
            },
            set: { newValue in
                if let idx = self.symbolElementIndexMap[id],
                   self.symbolElements.indices.contains(idx) {
                    self.symbolElements[idx] = .primitive(newValue)
                }
            }
        )
    }
}

import SwiftUI

enum EditorTab: String, CaseIterable, Identifiable {
    case elements  = "Elements"
    case geometry  = "Geometry"
    var id: Self { self }
}

struct EditorTabPicker: View {
    @Binding var selection: EditorTab
    var body: some View {
        Picker("", selection: $selection) {
            ForEach(EditorTab.allCases) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }
}
