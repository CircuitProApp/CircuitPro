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

    var footprintMode: FootprintStageMode = .create
    
    // MARK: - Component Metadata
    var componentName: String = "" {
        didSet {
            updateDynamicTextElements()
            refreshValidation()
        }
    }
    var referenceDesignatorPrefix: String = "" {
        didSet {
            updateDynamicTextElements()
            refreshValidation()
        }
    }
    var selectedCategory: ComponentCategory? { didSet { refreshValidation() } }
    var selectedPackageType: PackageType?

    var componentProperties: [PropertyDefinition] = [PropertyDefinition(key: nil, defaultValue: .single(nil), unit: .init())] {
        didSet {
            synchronizeSymbolTextWithProperties()
            updateDynamicTextElements()
            refreshValidation()
        }
    }

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

    // MARK: - Text Source Management
    private(set) var textSourceMap: [UUID: TextSource] = [:]
    private(set) var textDisplayOptionsMap: [UUID: TextDisplayOptions] = [:]

    var availableTextSources: [(displayName: String, source: TextSource)] {
        var sources: [(String, TextSource)] = []
        
        if !componentName.isEmpty { sources.append(("Name", .dynamic(.componentName))) }
        if !referenceDesignatorPrefix.isEmpty { sources.append(("Reference", .dynamic(.reference))) }
        
        for propDef in componentProperties where propDef.key?.label != nil && !propDef.key!.label.isEmpty {
            sources.append((propDef.key!.label, .dynamic(.property(definitionID: propDef.id))))
        }
        return sources
    }

    var placedTextSources: Set<TextSource> {
        return Set(textSourceMap.values)
    }

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
    
    // MARK: - Public Methods for Text Management
    
    func addTextToSymbol(source: TextSource, displayName: String) {
        guard !placedTextSources.contains(source) else { return }

        let defaultPaper = PaperSize.component
        let canvasSize = defaultPaper.canvasSize()
        let centerPoint = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        
        let newElementID = UUID()

        // Add the source and default options to maps so resolveText can find them
        textSourceMap[newElementID] = source
        if case .dynamic = source {
            textDisplayOptionsMap[newElementID] = .allVisible
        }
        
        // Resolve the text using the ID to get the full formatted string
        let resolvedText = resolveText(for: newElementID, source: source)

        let newElement = TextElement(
            id: newElementID,
            text: resolvedText.isEmpty ? displayName : resolvedText,
            position: centerPoint
        )
        
        symbolElements.append(.text(newElement))
    }
    
    // MARK: - Text Update and Sync Logic
    
    /// Gets the current display string for a given text element ID by resolving its source and applying options.
        private func resolveText(for elementID: UUID, source: TextSource) -> String {
            switch source {
            case .static(let text):
                return text
            case .dynamic(.componentName):
                return componentName
            case .dynamic(.reference):
                return referenceDesignatorPrefix
            case .dynamic(.property(let definitionID)):
                // This is a property, so we must format it using its specific display options.
                guard let prop = componentProperties.first(where: { $0.id == definitionID }) else {
                    return "Invalid Property"
                }
                
                // Get the options for this specific element from our map.
                let options = textDisplayOptionsMap[elementID, default: .allVisible]
                var parts: [String] = []
                
                if options.showKey, let label = prop.key?.label, !label.isEmpty {
                    parts.append("\(label):")
                }
                
                // THIS IS THE MODIFIED BLOCK
                if options.showValue {
                    let valueDescription = prop.defaultValue.description
                    if valueDescription.isEmpty {
                        // If the value is not set, show the placeholder.
                        parts.append("{{VALUE}}")
                    } else {
                        // Otherwise, show the actual value.
                        parts.append(valueDescription)
                    }
                }
                
                if options.showUnit, !prop.unit.symbol.isEmpty {
                    parts.append(prop.unit.symbol)
                }
                
                return parts.joined(separator: " ")
            }
        }
    
    /// Iterates through all dynamic text on the canvas and ensures its displayed text is up-to-date.
    private func updateDynamicTextElements() {
        for (elementID, source) in textSourceMap {
            guard let index = symbolElementIndexMap[elementID],
                  case .text(var textElement) = symbolElements[index] else {
                continue
            }
            
            // Resolve the text using the element's ID to apply the correct display options
            let newText = resolveText(for: elementID, source: source)
            
            if textElement.text != newText {
                textElement.text = newText
                symbolElements[index] = .text(textElement)
            }
        }
    }
    
    /// Removes text elements from the canvas if their underlying property definition was deleted.
    private func synchronizeSymbolTextWithProperties() {
        let validPropertyIDs = Set(componentProperties.map { $0.id })
        let textElementsToRemove = textSourceMap.filter { (elementID, source) in
            if case .dynamic(.property(let definitionID)) = source {
                return !validPropertyIDs.contains(definitionID)
            }
            return false
        }
        
        guard !textElementsToRemove.isEmpty else { return }
        
        let idsToRemove = Set(textElementsToRemove.keys)
        symbolElements.removeAll { idsToRemove.contains($0.id) }
    }
    
    // MARK: - Internal State Management
    
    private func updateSymbolIndexMap() {
        symbolElementIndexMap = Dictionary(
            uniqueKeysWithValues: symbolElements.enumerated().map { ($1.id, $0) }
        )
        
        let currentTextElementIDs = Set(symbolElements.compactMap { $0.asTextElement?.id })
        textSourceMap = textSourceMap.filter { currentTextElementIDs.contains($0.key) }
        textDisplayOptionsMap = textDisplayOptionsMap.filter { currentTextElementIDs.contains($0.key) }
    }

    private func updateFootprintIndexMap() {
        footprintElementIndexMap = Dictionary(
            uniqueKeysWithValues: footprintElements.enumerated().map { ($1.id, $0) }
        )
    }


    // MARK: - Reset All State
    func resetAll() {
        componentName = ""
        referenceDesignatorPrefix = ""
        selectedCategory = nil
        selectedPackageType = nil
        componentProperties = [PropertyDefinition(key: nil, defaultValue: .single(nil), unit: .init())]
        symbolElements = []
        selectedSymbolElementIDs = []
        selectedSymbolTool = AnyCanvasTool(CursorTool())
        textSourceMap = [:]
        textDisplayOptionsMap = [:]
        footprintElements = []
        selectedFootprintElementIDs = []
        selectedFootprintTool = AnyCanvasTool(CursorTool())
        selectedFootprintLayer = .layer0
        layerAssignments = [:]
        validationSummary = ValidationSummary()
        showFieldErrors = false
    }

    // MARK: - Validation (Unchanged)
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
}


// MARK: - Symbol Text Display Options
extension ComponentDesignManager {
    /// Creates a `Binding` for a specific text element's display options.
    /// This allows the UI to modify how a dynamic property is displayed (e.g., toggling key/value/unit).
    ///
    /// - Parameter id: The `UUID` of the text element.
    /// - Returns: An optional `Binding<TextDisplayOptions>`.
    func bindingForDisplayOptions(with id: UUID) -> Binding<TextDisplayOptions>? {
        guard let source = textSourceMap[id], case .dynamic = source else {
            return nil
        }
        
        return Binding<TextDisplayOptions>(
            get: {
                return self.textDisplayOptionsMap[id, default: .allVisible]
            },
            set: { newOptions in
                self.textDisplayOptionsMap[id] = newOptions
                // ADDED: Refresh the canvas when an option changes.
                self.updateDynamicTextElements()
            }
        )
    }
}
