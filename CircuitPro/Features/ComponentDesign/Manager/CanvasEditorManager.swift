//
//  CanvasEditorManager.swift
//  CircuitPro
//
//  Created by Gemini on 8/1/25.
//

import SwiftUI
import Observation

@Observable
final class CanvasEditorManager {

    // MARK: - Canvas State
    var elements: [CanvasElement] = [] {
        didSet {
            updateElementIndexMap()
        }
    }
    var selectedElementIDs: Set<UUID> = []
    var selectedTool: AnyCanvasTool = AnyCanvasTool(CursorTool())
    private var elementIndexMap: [UUID: Int] = [:]

    // MARK: - Layer State (Primarily for Footprint)
    var selectedLayer: CanvasLayer? = .layer0
    var layerAssignments: [UUID: CanvasLayer] = [:]

    // MARK: - Text State
    private(set) var textSourceMap: [UUID: TextSource] = [:]
    private(set) var textDisplayOptionsMap: [UUID: TextDisplayOptions] = [:]

    // MARK: - Computed Properties
    var pins: [Pin] {
        elements.compactMap { $0.asPin }
    }

    var pads: [Pad] {
        elements.compactMap { $0.asPad }
    }
    
    var placedTextSources: Set<TextSource> {
        return Set(textSourceMap.values)
    }

    // MARK: - Initializer
    init() {}

    // MARK: - State Management
    private func updateElementIndexMap() {
        elementIndexMap = Dictionary(
            uniqueKeysWithValues: elements.enumerated().map { ($1.id, $0) }
        )
        
        // Prune any text source mappings that no longer have a corresponding element
        let currentTextElementIDs = Set(elements.compactMap { $0.asTextElement?.id })
        textSourceMap = textSourceMap.filter { currentTextElementIDs.contains($0.key) }
        textDisplayOptionsMap = textDisplayOptionsMap.filter { currentTextElementIDs.contains($0.key) }
    }
    
    func reset() {
        elements = []
        selectedElementIDs = []
        selectedTool = AnyCanvasTool(CursorTool())
        elementIndexMap = [:]
        selectedLayer = .layer0
        layerAssignments = [:]
        textSourceMap = [:]
        textDisplayOptionsMap = [:]
    }
}

// MARK: - Text Management
extension CanvasEditorManager {
    
    /// Adds a new text element to the canvas, linked to a specific data source.
    func addTextToSymbol(source: TextSource, displayName: String, componentData: (name: String, prefix: String, properties: [PropertyDefinition])) {
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
        
        let resolvedText = resolveText(for: newElementID, source: source, componentData: componentData)

        let newElement = TextElement(
            id: newElementID,
            text: resolvedText.isEmpty ? displayName : resolvedText,
            position: centerPoint
        )
        
        elements.append(.text(newElement))
    }
    
    /// Iterates through all dynamic text on the canvas and ensures its displayed text is up-to-date with the latest component data.
    func updateDynamicTextElements(componentData: (name: String, prefix: String, properties: [PropertyDefinition])) {
        for (elementID, source) in textSourceMap {
            guard let index = elementIndexMap[elementID],
                  case .text(var textElement) = elements[index] else {
                continue
            }
            
            let newText = resolveText(for: elementID, source: source, componentData: componentData)
            
            if textElement.text != newText {
                textElement.text = newText
                elements[index] = .text(textElement)
            }
        }
    }

    /// Removes text elements from the canvas if their underlying property definition was deleted from the component.
    func synchronizeSymbolTextWithProperties(properties: [PropertyDefinition]) {
        let validPropertyIDs = Set(properties.map { $0.id })
        let textElementsToRemove = textSourceMap.filter { (_, source) in
            if case .dynamic(.property(let definitionID)) = source {
                return !validPropertyIDs.contains(definitionID)
            }
            return false
        }
        
        guard !textElementsToRemove.isEmpty else { return }
        
        let idsToRemove = Set(textElementsToRemove.keys)
        elements.removeAll { idsToRemove.contains($0.id) }
    }
    
    /// Gets the current display string for a given text element ID by resolving its source and applying display options.
    private func resolveText(for elementID: UUID, source: TextSource, componentData: (name: String, prefix: String, properties: [PropertyDefinition])) -> String {
        switch source {
        case .static(let text):
            return text
        case .dynamic(.componentName):
            return componentData.name
        case .dynamic(.reference):
            return componentData.prefix
        case .dynamic(.property(let definitionID)):
            guard let prop = componentData.properties.first(where: { $0.id == definitionID }) else {
                return "Invalid Property"
            }
            
            let options = textDisplayOptionsMap[elementID, default: .allVisible]
            var parts: [String] = []
            
            if options.showKey, let label = prop.key?.label, !label.isEmpty {
                parts.append("\(label):")
            }
            
            if options.showValue {
                let valueDescription = prop.defaultValue.description
                parts.append(valueDescription.isEmpty ? "{{VALUE}}" : valueDescription)
            }
            
            if options.showUnit, !prop.unit.symbol.isEmpty {
                parts.append(prop.unit.symbol)
            }
            
            return parts.joined(separator: " ")
        }
    }
    
    /// Creates a `Binding` for a specific text element's display options.
    func bindingForDisplayOptions(with id: UUID, componentData: (name: String, prefix: String, properties: [PropertyDefinition])) -> Binding<TextDisplayOptions>? {
        guard let source = textSourceMap[id], case .dynamic = source else {
            return nil
        }
        
        return Binding<TextDisplayOptions>(
            get: {
                return self.textDisplayOptionsMap[id, default: .allVisible]
            },
            set: { newOptions in
                self.textDisplayOptionsMap[id] = newOptions
                self.updateDynamicTextElements(componentData: componentData)
            }
        )
    }
}
