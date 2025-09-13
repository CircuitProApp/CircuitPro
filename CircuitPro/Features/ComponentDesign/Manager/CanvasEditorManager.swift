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
    
    var canvasNodes: [BaseNode] = [] {
        didSet { updateElementIndexMap() }
    }
    
    var selectedElementIDs: Set<UUID> = []
    
    var singleSelectedNode: BaseNode? {
        guard selectedElementIDs.count == 1,
              let id = selectedElementIDs.first,
              let index = elementIndexMap[id] else {
            return nil
        }
        return canvasNodes[index]
    }
    
    var selectedTool: CanvasTool = CursorTool()
    private var elementIndexMap: [UUID: Int] = [:]
    
    /// NEW: Since placeholder text is now view-state, not model-state, this map
    /// holds the currently displayed string for each text node.
    var displayTextMap: [UUID: String] = [:]
    
    // MARK: - Layer State
    
    var layers: [CanvasLayer] = []
    var activeLayerId: UUID?
    
    // MARK: - Computed Properties
    
    var pins: [Pin] {
        canvasNodes.compactMap { ($0 as? PinNode)?.pin }
    }
    
    var pads: [Pad] {
        canvasNodes.compactMap { ($0 as? PadNode)?.pad }
    }
    
    /// UPDATED: This now inspects the `resolvedText.content` property.
    var placedTextContents: Set<CircuitTextContent> {
        let contents = canvasNodes.compactMap { ($0 as? TextNode)?.resolvedText.content }
        return Set(contents)
    }
    
    // MARK: - State Management
    
    private func updateElementIndexMap() {
        elementIndexMap = Dictionary(
            uniqueKeysWithValues: canvasNodes.enumerated().map { ($1.id, $0) }
        )
        // Also prune the display text map.
        let currentNodeIDs = Set(canvasNodes.map(\.id))
        displayTextMap = displayTextMap.filter { currentNodeIDs.contains($0.key) }
    }
    
    func setupForFootprintEditing() {
        self.layers = LayerKind.footprintLayers.map { kind in
            CanvasLayer(
                id: kind.stableId,
                name: kind.label,
                isVisible: true,
                color: NSColor(kind.defaultColor).cgColor,
                zIndex: kind.zIndex,
                kind: kind
            )
        }
        self.layers.append(self.unlayeredSection)
        self.activeLayerId = self.layers.first?.id
    }
    
    private let unlayeredSection: CanvasLayer = .init(
        id: .init(),
        name: "Unlayered",
        isVisible: true,
        color: NSColor.gray.cgColor,
        zIndex: -1
    )
    
    func reset() {
        canvasNodes = []
        selectedElementIDs = []
        selectedTool = CursorTool()
        elementIndexMap = [:]
        displayTextMap = [:] // Reset the new map
        layers = []
        activeLayerId = nil
    }
}

// MARK: - Text Management
extension CanvasEditorManager {
    
    /// REWRITTEN: Creates text based on the new `CircuitTextContent` model.
    func addTextToSymbol(content: CircuitTextContent, componentData: (name: String, prefix: String, properties: [Property.Definition])) {
        // Prevent adding duplicate functional texts like 'Component Name'.
        if !content.isStatic {
            guard !placedTextContents.contains(where: { $0.isSameType(as: content) }) else { return }
        }
        
        let newElementID = UUID()
        let centerPoint = CGPoint(x: PaperSize.component.canvasSize().width / 2, y: PaperSize.component.canvasSize().height / 2)
        
        // This assumes a new Resolvable model where `id` is the identity and `content` is an overridable property.
        let tempDefinition = CircuitText.Definition(
            id: newElementID,
            content: content,
            relativePosition: centerPoint,
            anchorPosition: centerPoint,
            font: .init(font: .systemFont(ofSize: 12)),
            color: .init(color: .init(nsColor: .black)),
            anchor: .leading,
            alignment: .center,
            cardinalRotation: .east,
            isVisible: true
        )
        
        let resolvedText = CircuitText.Resolver.resolve(definition: tempDefinition, override: nil)
        
        // Populate the placeholder text and store it in our display map.
        let placeholder = self.resolveText(for: resolvedText.content, componentData: componentData)
        self.displayTextMap[newElementID] = placeholder
        
        // --- THIS IS THE FIX ---
        // Pass the generated `placeholder` string to the TextNode initializer.
        let newNode = TextNode(id: newElementID, resolvedText: resolvedText, text: placeholder)
        
        canvasNodes.append(newNode)
    }

    /// REWRITTEN: Updates placeholder text in the `displayTextMap`.
    func updateDynamicTextElements(componentData: (name: String, prefix: String, properties: [Property.Definition])) {
        for node in canvasNodes {
            guard let textNode = node as? TextNode else { continue }
            
            // Re-resolve the placeholder string.
            let newText = resolveText(for: textNode.resolvedText.content, componentData: componentData)
            
            // Update the display map. The canvas view must observe this change.
            if displayTextMap[textNode.id] != newText {
                displayTextMap[textNode.id] = newText
            }
        }
    }
    
    /// UPDATED: Switches on the new `content` enum.
    func synchronizeSymbolTextWithProperties(properties: [Property.Definition]) {
        let validPropertyIDs = Set(properties.map { $0.id })
        
        let idsToRemove = canvasNodes.compactMap { node -> UUID? in
            guard let textNode = node as? TextNode,
                  case .componentProperty(let definitionID, _) = textNode.resolvedText.content else {
                return nil
            }
            return validPropertyIDs.contains(definitionID) ? nil : textNode.id
        }
        
        guard !idsToRemove.isEmpty else { return }
        canvasNodes.removeAll { idsToRemove.contains($0.id) }
        selectedElementIDs.subtract(idsToRemove)
        // displayTextMap will be pruned automatically by the canvasNodes.didSet observer.
    }
    
    /// REWRITTEN: Takes a `CircuitTextContent` and resolves the placeholder string.
    private func resolveText(for content: CircuitTextContent, componentData: (name: String, prefix: String, properties: [Property.Definition])) -> String {
        switch content {
        case .static(let text):
            return text
            
        case .componentName:
            return componentData.name.isEmpty ? "Name" : componentData.name
            
        case .componentReferenceDesignator:
            return componentData.prefix.isEmpty ? "REF?" : componentData.prefix + "?"
            
        case .componentProperty(let definitionID, let options):
            guard let prop = componentData.properties.first(where: { $0.id == definitionID }) else {
                return "Invalid Property"
            }
            
            var parts: [String] = []
            if options.showKey { parts.append("\(prop.key.label):") }
            if options.showValue { parts.append(prop.value.description.isEmpty ? "?" : prop.value.description) }
            if options.showUnit, !prop.unit.symbol.isEmpty { parts.append(prop.unit.symbol) }
            return parts.joined(separator: " ")
        }
    }
    
    /// REWRITTEN: Creates a custom binding to an enum's associated value.
    func bindingForDisplayOptions(with id: UUID) -> Binding<TextDisplayOptions>? {
        guard let index = elementIndexMap[id],
              let textNode = canvasNodes[index] as? TextNode,
              case .componentProperty(let definitionID, _) = textNode.resolvedText.content else {
            return nil
        }
        
        return Binding<TextDisplayOptions>(
            get: {
                // Safely extract the options from the current content enum.
                if case .componentProperty(_, let options) = textNode.resolvedText.content {
                    return options
                }
                return .default // Fallback
            },
            set: { newOptions in
                // Reconstruct the enum with the new options and assign it back to the model.
                // This triggers the `didSet` in the TextNode, persisting the change.
                textNode.resolvedText.content = .componentProperty(definitionID: definitionID, options: newOptions)
            }
        )
    }
    
    /// UPDATED: Switches on the new `content` enum.
    func removeTextFromSymbol(content: CircuitTextContent) {
        let idsToRemove = canvasNodes.compactMap { node -> UUID? in
            guard let textNode = node as? TextNode,
                  textNode.resolvedText.content.isSameType(as: content) else {
                return nil
            }
            return textNode.id
        }
        
        guard !idsToRemove.isEmpty else { return }
        canvasNodes.removeAll { idsToRemove.contains($0.id) }
        selectedElementIDs.subtract(idsToRemove)
    }
}


// Add this helper to your CircuitTextContent enum to simplify checking.
extension CircuitTextContent {
    var isStatic: Bool {
        if case .static = self { return true }
        return false
    }

    /// Compares if two enum cases are of the same type, ignoring associated values.
    func isSameType(as other: CircuitTextContent) -> Bool {
        switch (self, other) {
        case (.static, .static): return true // Note: You might want to compare text for static
        case (.componentName, .componentName): return true
        case (.componentReferenceDesignator, .componentReferenceDesignator): return true
        case (.componentProperty(let id1, _), .componentProperty(let id2, _)): return id1 == id2
        default: return false
        }
    }
}
