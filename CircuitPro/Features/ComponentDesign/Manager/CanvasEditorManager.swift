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

    var layers: [CanvasLayer] = []
    var activeLayerId: UUID?

    // MARK: - Computed Properties

    var pins: [Pin] {
        items.compactMap { ($0 as? CanvasPin)?.pin }
    }

    var pads: [Pad] {
        items.compactMap { ($0 as? CanvasPad)?.pad }
    }

    var primitives: [AnyCanvasPrimitive] {
        items.compactMap { item in
            if let primitive = item as? AnyCanvasPrimitive {
                return primitive
            }
            if let element = item as? CanvasPrimitiveElement {
                return element.primitive
            }
            return nil
        }
    }

    /// UPDATED: This now inspects the `resolvedText.content` property.
    var placedTextContents: Set<CircuitTextContent> {
        let contents = items.compactMap { ($0 as? CanvasText)?.resolvedText.content }
        return Set(contents)
    }

    // MARK: - State Management

    init(textTarget: TextTarget = .symbol) {
        self.textTarget = textTarget
        self.textOwnerID = UUID()
    }

    struct ElementItem: Identifiable {
        enum Kind {
            case primitive(AnyCanvasPrimitive)
            case text(CanvasText)
            case pin(CanvasPin)
            case pad(CanvasPad)
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
            case .text(let text):
                return text.layerId
            case .pin:
                return nil
            case .pad(let pad):
                return pad.layerId
            }
        }
    }

    var elementItems: [ElementItem] {
        items.compactMap { item in
            if let primitive = item as? AnyCanvasPrimitive {
                return ElementItem(kind: .primitive(primitive))
            }
            if let element = item as? CanvasPrimitiveElement {
                return ElementItem(kind: .primitive(element.primitive))
            }
            if let text = item as? CanvasText {
                return ElementItem(kind: .text(text))
            }
            if let pin = item as? CanvasPin {
                return ElementItem(kind: .pin(pin))
            }
            if let pad = item as? CanvasPad {
                return ElementItem(kind: .pad(pad))
            }
            return nil
        }
    }

    var singleSelectedPrimitive: (id: UUID, primitive: AnyCanvasPrimitive)? {
        guard selectedElementIDs.count == 1, let id = selectedElementIDs.first else { return nil }
        if let primitive = items.first(where: { $0.id == id }) as? AnyCanvasPrimitive {
            return (id, primitive)
        }
        if let element = items.first(where: { $0.id == id }) as? CanvasPrimitiveElement {
            return (id, element.primitive)
        }
        return nil
    }

    var singleSelectedText: (id: UUID, text: CanvasText)? {
        guard let (id, text) = singleSelectedItem(as: CanvasText.self) else { return nil }
        return (id, text)
    }

    var singleSelectedPin: (id: UUID, pin: CanvasPin)? {
        guard let (id, pin) = singleSelectedItem(as: CanvasPin.self) else { return nil }
        return (id, pin)
    }

    var singleSelectedPad: (id: UUID, pad: CanvasPad)? {
        guard let (id, pad) = singleSelectedItem(as: CanvasPad.self) else { return nil }
        return (id, pad)
    }

    private func singleSelectedItem<T>(as type: T.Type) -> (UUID, T)? {
        guard selectedElementIDs.count == 1, let id = selectedElementIDs.first else { return nil }
        guard let item = items.first(where: { $0.id == id }) as? T else { return nil }
        return (id, item)
    }

    func primitiveBinding(for id: UUID) -> Binding<AnyCanvasPrimitive>? {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }

        let fallback: AnyCanvasPrimitive
        if let primitive = items[index] as? AnyCanvasPrimitive {
            fallback = primitive
        } else if let element = items[index] as? CanvasPrimitiveElement {
            fallback = element.primitive
        } else {
            return nil
        }

        return Binding(
            get: {
                if let current = self.items.first(where: { $0.id == id }) as? AnyCanvasPrimitive {
                    return current
                }
                if let element = self.items.first(where: { $0.id == id }) as? CanvasPrimitiveElement {
                    return element.primitive
                }
                return fallback
            },
            set: { newPrimitive in
                guard let currentIndex = self.items.firstIndex(where: { $0.id == id }) else { return }
                if var current = self.items[currentIndex] as? CanvasPrimitiveElement {
                    current.primitive = newPrimitive
                    self.items[currentIndex] = current
                } else {
                    self.items[currentIndex] = newPrimitive
                }
            }
        )
    }

    func textBinding(for id: UUID) -> Binding<CanvasText>? {
        guard let index = items.firstIndex(where: { $0.id == id }),
              let component = items[index] as? CanvasText else { return nil }
        let fallback = component
        return Binding(
            get: {
                guard let current = self.items.first(where: { $0.id == id }) as? CanvasText else {
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
              let component = items[index] as? CanvasPin else { return nil }
        let fallback = component.pin
        return Binding(
            get: {
                guard let current = self.items.first(where: { $0.id == id }) as? CanvasPin else {
                    return fallback
                }
                return current.pin
            },
            set: { newPin in
                guard let currentIndex = self.items.firstIndex(where: { $0.id == id }),
                      var current = self.items[currentIndex] as? CanvasPin else {
                    return
                }
                current.pin = newPin
                self.items[currentIndex] = current
            }
        )
    }

    func padBinding(for id: UUID) -> Binding<Pad>? {
        guard let index = items.firstIndex(where: { $0.id == id }),
              let component = items[index] as? CanvasPad else {
            return nil
        }
        let fallback = component.pad
        return Binding(
            get: {
                guard let current = self.items.first(where: { $0.id == id }) as? CanvasPad else {
                    return fallback
                }
                return current.pad
            },
            set: { newPad in
                guard let currentIndex = self.items.firstIndex(where: { $0.id == id }),
                      var current = self.items[currentIndex] as? CanvasPad else {
                    return
                }
                current.pad = newPad
                self.items[currentIndex] = current
            }
        )
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

    /// REWRITTEN: Creates text based on the new `CircuitTextContent` model.
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

        let placeholder = self.resolveText(for: resolvedText.content, componentData: componentData)
        let component = CanvasText(
            resolvedText: resolvedText,
            displayText: placeholder,
            ownerID: textOwnerID,
            target: textTarget,
            ownerPosition: .zero,
            ownerRotation: 0,
            layerId: activeLayerId,
            showsAnchorGuides: false
        )

        items.append(component)
    }

    /// REWRITTEN: Updates placeholder text in the item-backed text components.
    func updateDynamicTextElements(
        componentData: (name: String, prefix: String, properties: [Property.Definition])
    ) {
        for index in items.indices {
            guard var component = items[index] as? CanvasText else { continue }
            guard !component.resolvedText.content.isStatic else { continue }
            let newText = resolveText(
                for: component.resolvedText.content, componentData: componentData)
            guard component.displayText != newText else { continue }
            component.displayText = newText
            items[index] = component
        }
    }

    /// UPDATED: Switches on the new `content` enum.
    func synchronizeSymbolTextWithProperties(properties: [Property.Definition]) {
        let validPropertyIDs = Set(properties.map { $0.id })

        var idsToRemove = Set<UUID>()
        for item in items {
            guard let component = item as? CanvasText else { continue }
            guard case .componentProperty(let definitionID, _) = component.resolvedText.content else {
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

    /// REWRITTEN: Takes a `CircuitTextContent` and resolves the placeholder string.
    private func resolveText(
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

    /// REWRITTEN: Creates a custom binding to an enum's associated value.
    func bindingForDisplayOptions(
        with id: UUID,
        componentData: (name: String, prefix: String, properties: [Property.Definition])
    ) -> Binding<TextDisplayOptions>? {
        guard let component = items.first(where: { $0.id == id }) as? CanvasText,
              case .componentProperty(let definitionID, _) = component.resolvedText.content
        else {
            return nil
        }

        return Binding<TextDisplayOptions>(
            get: {
                guard let current = self.items.first(where: { $0.id == id }) as? CanvasText,
                      case .componentProperty(_, let options) = current.resolvedText.content
                else {
                    return .default
                }
                return options
            },
            set: { newOptions in
                guard let currentIndex = self.items.firstIndex(where: { $0.id == id }),
                      var current = self.items[currentIndex] as? CanvasText else {
                    return
                }
                current.resolvedText.content = .componentProperty(
                    definitionID: definitionID, options: newOptions)
                current.displayText = self.resolveText(
                    for: current.resolvedText.content, componentData: componentData)
                self.items[currentIndex] = current
            }
        )
    }

    /// UPDATED: Switches on the new `content` enum.
    func removeTextFromSymbol(content: CircuitTextContent) {
        let idsToRemove = items.compactMap { item -> UUID? in
            guard let component = item as? CanvasText else { return nil }
            return component.resolvedText.content.isSameType(as: content) ? component.id : nil
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
