//
//  CanvasEditorManager.swift
//  CircuitPro
//
//  Created by Gemini on 8/1/25.
//

import Observation
import SwiftUI

@MainActor
@Observable
final class CanvasEditorManager {

    // MARK: - Canvas State

    let textTarget: TextTarget
    let textOwnerID: UUID

    var items: [any CanvasItem] = []
    var selectedElementIDs: Set<UUID> = []
    var selectedTool: CanvasTool = CursorTool()

    // MARK: - Layer State

    var layers: [any CanvasLayer] = []
    var activeLayerId: UUID?

    // MARK: - Computed Properties

    var pins: [Pin] {
        items.compactMap { $0 as? Pin }
    }

    var pads: [Pad] {
        items.compactMap { $0 as? Pad }
    }

    var primitives: [AnyCanvasPrimitive] {
        items.compactMap { $0 as? AnyCanvasPrimitive }
    }

    var textDefinitions: [CircuitText.Definition] {
        items.compactMap { $0 as? CircuitText.Definition }
    }

    /// UPDATED: This now inspects the `content` property.
    var placedTextContents: Set<CircuitTextContent> {
        Set(textDefinitions.map { $0.content })
    }

    private var componentData: (name: String, prefix: String, properties: [Property.Definition]) = (
        name: "",
        prefix: "",
        properties: []
    )

    // MARK: - State Management

    init(textTarget: TextTarget = .symbol) {
        self.textTarget = textTarget
        self.textOwnerID = UUID()
    }

    struct ElementItem: Identifiable {
        enum Kind {
            case primitive(AnyCanvasPrimitive)
            case text(CircuitText.Definition)
            case pin(Pin)
            case pad(Pad)
        }

        let kind: Kind

        var id: UUID {
            switch kind {
            case .primitive(let primitive): return primitive.id
            case .text(let text): return text.id
            case .pin(let pin): return pin.id
            case .pad(let pad): return pad.id
            }
        }

        var layerId: UUID? {
            switch kind {
            case .primitive(let primitive):
                return primitive.layerId
            case .text:
                return nil
            case .pin:
                return nil
            case .pad:
                return nil
            }
        }
    }

    var elementItems: [ElementItem] {
        items.compactMap { item in
            if let primitive = item as? AnyCanvasPrimitive {
                return ElementItem(kind: .primitive(primitive))
            }
            if let text = item as? CircuitText.Definition {
                return ElementItem(kind: .text(text))
            }
            if let pin = item as? Pin {
                return ElementItem(kind: .pin(pin))
            }
            if let pad = item as? Pad {
                return ElementItem(kind: .pad(pad))
            }
            return nil
        }
    }

    var singleSelectedPrimitive: (id: UUID, primitive: AnyCanvasPrimitive)? {
        guard selectedElementIDs.count == 1, let id = selectedElementIDs.first else { return nil }
        guard let primitive = items.first(where: { $0.id == id }) as? AnyCanvasPrimitive else {
            return nil
        }
        return (id, primitive)
    }

    var singleSelectedText: (id: UUID, text: CircuitText.Definition)? {
        guard selectedElementIDs.count == 1, let id = selectedElementIDs.first else { return nil }
        guard let text = items.first(where: { $0.id == id }) as? CircuitText.Definition else {
            return nil
        }
        return (id, text)
    }

    var singleSelectedPin: (id: UUID, pin: Pin)? {
        guard selectedElementIDs.count == 1, let id = selectedElementIDs.first else { return nil }
        guard let pin = items.first(where: { $0.id == id }) as? Pin else { return nil }
        return (id, pin)
    }

    var singleSelectedPad: (id: UUID, pad: Pad)? {
        guard selectedElementIDs.count == 1, let id = selectedElementIDs.first else { return nil }
        guard let pad = items.first(where: { $0.id == id }) as? Pad else { return nil }
        return (id, pad)
    }

    func primitiveBinding(for id: UUID) -> Binding<AnyCanvasPrimitive>? {
        guard let index = items.firstIndex(where: { $0.id == id }),
              let primitive = items[index] as? AnyCanvasPrimitive else {
            return nil
        }
        let fallback = primitive
        return Binding(
            get: {
                guard let current = self.items.first(where: { $0.id == id }) as? AnyCanvasPrimitive else {
                    return fallback
                }
                return current
            },
            set: { newPrimitive in
                guard let currentIndex = self.items.firstIndex(where: { $0.id == id }) else { return }
                self.items[currentIndex] = newPrimitive
            }
        )
    }

    func textBinding(for id: UUID) -> Binding<CircuitText.Definition>? {
        guard let index = items.firstIndex(where: { $0.id == id }),
              let text = items[index] as? CircuitText.Definition else { return nil }
        let fallback = text
        return Binding(
            get: {
                guard let current = self.items.first(where: { $0.id == id }) as? CircuitText.Definition else {
                    return fallback
                }
                return current
            },
            set: { newValue in
                guard let currentIndex = self.items.firstIndex(where: { $0.id == id }) else { return }
                self.items[currentIndex] = newValue
            }
        )
    }

    func pinBinding(for id: UUID) -> Binding<Pin>? {
        guard let index = items.firstIndex(where: { $0.id == id }),
              let pin = items[index] as? Pin else { return nil }
        let fallback = pin
        return Binding(
            get: {
                guard let current = self.items.first(where: { $0.id == id }) as? Pin else {
                    return fallback
                }
                return current
            },
            set: { newPin in
                guard let currentIndex = self.items.firstIndex(where: { $0.id == id }) else { return }
                self.items[currentIndex] = newPin
            }
        )
    }

    func padBinding(for id: UUID) -> Binding<Pad>? {
        guard let index = items.firstIndex(where: { $0.id == id }),
              let pad = items[index] as? Pad else {
            return nil
        }
        let fallback = pad
        return Binding(
            get: {
                guard let current = self.items.first(where: { $0.id == id }) as? Pad else {
                    return fallback
                }
                return current
            },
            set: { newPad in
                guard let currentIndex = self.items.firstIndex(where: { $0.id == id }) else { return }
                self.items[currentIndex] = newPad
            }
        )
    }

    func setupForFootprintEditing() {
        self.layers = LayerKind.footprintLayers.map { kind in
            PCBLayer(kind: kind)
        }
        self.layers.append(self.unlayeredSection)
        self.activeLayerId = self.layers.first?.id
    }

    private let unlayeredSection: PCBLayer = .init(
        id: .init(),
        name: "Unlayered",
        isVisible: true,
        color: NSColor.gray.cgColor,
        zIndex: -1
    )

    func reset() {
        selectedElementIDs = []
        items = []
        selectedTool = CursorTool()
        layers = []
        activeLayerId = nil
    }

    // Canvas items should live in the items array; no graph-based storage.
}

// MARK: - Text Management
extension CanvasEditorManager {

    /// Creates text based on the `CircuitTextContent` model.
    func addTextToSymbol(
        content: CircuitTextContent,
        componentData: (name: String, prefix: String, properties: [Property.Definition])
    ) {
        // Prevent adding duplicate functional texts like 'Component Name'.
        if !content.isStatic {
            guard !placedTextContents.contains(where: { $0.isSameType(as: content) }) else {
                return
            }
        }

        let newElementID = UUID()
        let centerPoint = CGPoint(
            x: PaperSize.component.canvasSize().width / 2,
            y: PaperSize.component.canvasSize().height / 2)

        let definition = CircuitText.Definition(
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

        _ = componentData
        items.append(definition)
    }

    /// Dynamic text is resolved at render time; nothing to persist here.
    func updateDynamicTextElements(
        componentData: (name: String, prefix: String, properties: [Property.Definition])
    ) {
        self.componentData = componentData
    }

    /// Removes property text entries that no longer exist.
    func synchronizeSymbolTextWithProperties(properties: [Property.Definition]) {
        let validPropertyIDs = Set(properties.map { $0.id })

        var idsToRemove = Set<UUID>()
        for item in items {
            guard let component = item as? CircuitText.Definition else { continue }
            guard case .componentProperty(let definitionID, _) = component.content else {
                continue
            }
            if !validPropertyIDs.contains(definitionID) {
                idsToRemove.insert(component.id)
            }
        }

        guard !idsToRemove.isEmpty else { return }
        items.removeAll { idsToRemove.contains($0.id) }
        selectedElementIDs.subtract(idsToRemove)
    }

    /// Resolves placeholder strings for dynamic text when needed by the UI.
    func resolveText(
        for content: CircuitTextContent,
        componentData: (name: String, prefix: String, properties: [Property.Definition])
    ) -> String {
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
            if options.showValue {
                parts.append(prop.value.description.isEmpty ? "?" : prop.value.description)
            }
            if options.showUnit, !prop.unit.symbol.isEmpty { parts.append(prop.unit.symbol) }
            return parts.joined(separator: " ")
        }
    }

    func resolveText(_ definition: CircuitText.Definition) -> String {
        resolveText(for: definition.content, componentData: componentData)
    }

    /// Creates a binding to a component property text's display options.
    func bindingForDisplayOptions(
        with id: UUID,
        componentData: (name: String, prefix: String, properties: [Property.Definition])
    ) -> Binding<TextDisplayOptions>? {
        guard let component = items.first(where: { $0.id == id }) as? CircuitText.Definition,
              case .componentProperty(let definitionID, _) = component.content
        else {
            return nil
        }

        return Binding<TextDisplayOptions>(
            get: {
                guard let current = self.items.first(where: { $0.id == id }) as? CircuitText.Definition,
                      case .componentProperty(_, let options) = current.content
                else {
                    return .default
                }
                return options
            },
            set: { newOptions in
                guard let currentIndex = self.items.firstIndex(where: { $0.id == id }),
                      var current = self.items[currentIndex] as? CircuitText.Definition else {
                    return
                }
                current.content = .componentProperty(
                    definitionID: definitionID, options: newOptions)
                self.items[currentIndex] = current
            }
        )
    }

    /// Removes a text item from the canvas.
    func removeTextFromSymbol(content: CircuitTextContent) {
        let idsToRemove = items.compactMap { item -> UUID? in
            guard let component = item as? CircuitText.Definition else { return nil }
            return component.content.isSameType(as: content) ? component.id : nil
        }

        guard !idsToRemove.isEmpty else { return }
        let ids = Set(idsToRemove)
        items.removeAll { ids.contains($0.id) }
        selectedElementIDs.subtract(ids)
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
        case (.static, .static): return true  // Note: You might want to compare text for static
        case (.componentName, .componentName): return true
        case (.componentReferenceDesignator, .componentReferenceDesignator): return true
        case (.componentProperty(let id1, _), .componentProperty(let id2, _)): return id1 == id2
        default: return false
        }
    }
}
