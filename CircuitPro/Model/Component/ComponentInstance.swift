//
//  ComponentInstance.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/14/25.
//

import Observation
import SwiftUI
import Resolvable

@Observable
@ResolvableDestination(for: Property.self)
final class ComponentInstance: Identifiable, Codable {

    var id: UUID
    var definitionUUID: UUID

    @DefinitionSource(for: Property.self, at: \ComponentDefinition.propertyDefinitions)
    var definition: ComponentDefinition? = nil

    var propertyOverrides: [Property.Override]
    var propertyInstances: [Property.Instance]

    var symbolInstance: SymbolInstance
    var footprintInstance: FootprintInstance?

    var referenceDesignatorIndex: Int

    init(
        id: UUID = UUID(),
        definitionUUID: UUID,
        definition: ComponentDefinition? = nil,
        propertyOverrides: [Property.Override] = [],
        propertyInstances: [Property.Instance] = [],
        symbolInstance: SymbolInstance,
        footprintInstance: FootprintInstance? = nil,
        reference: Int = 0
    ) {
        self.id = id
        self.definitionUUID = definitionUUID
        self.definition = definition
        self.propertyOverrides = propertyOverrides
        self.propertyInstances = propertyInstances
        self.symbolInstance = symbolInstance
        self.footprintInstance = footprintInstance
        self.referenceDesignatorIndex = reference
    }

    enum CodingKeys: String, CodingKey {
        case _id = "id"
        case _definitionUUID = "definitionUUID"
        case _propertyOverrides = "propertyOverrides"
        case _propertyInstances = "propertyInstances"
        case _symbolInstance = "symbolInstance"
        case _footprintInstance = "footprintInstance"
        case _referenceDesignatorIndex = "referenceDesignatorIndex"
    }
}

// MARK: - Hashable
extension ComponentInstance: Hashable {
    public static func == (lhs: ComponentInstance, rhs: ComponentInstance) -> Bool {
        lhs.id == rhs.id
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension ComponentInstance {
    /// A helper to resolve the properties of this specific instance.
    /// This replaces the logic that was previously on `DesignComponent`.
    var displayedProperties: [Property.Resolved] {
        // Gracefully handle the case where the definition is missing.
        guard let definition = self.definition else { return [] }

        return Property.Resolver.resolve(
            definitions: definition.propertyDefinitions,
            overrides: self.propertyOverrides,
            instances: self.propertyInstances
        )
    }
}

extension ComponentInstance {

    // MARK: Lookup
    private func resolvedText(
        matching content: CircuitTextContent,
        in target: TextTarget
    ) -> CircuitText.Resolved? {
        switch target {
        case .symbol:
            return symbolInstance.resolvedItems.first { $0.content.isSameType(as: content) }
        case .footprint:
            return footprintInstance?.resolvedItems.first { $0.content.isSameType(as: content) }
        }
    }

    // MARK: Visibility
    func isTextVisible(_ content: CircuitTextContent, for target: TextTarget) -> Bool {
        resolvedText(matching: content, in: target)?.isVisible ?? false
    }

    func toggleTextVisibility(_ content: CircuitTextContent, for target: TextTarget) {
        switch target {
        case .symbol:
            guard var r = symbolInstance.resolvedItems.first(where: { $0.content.isSameType(as: content) }) else { return }
            r.isVisible.toggle()
            symbolInstance.apply(r)     // <- ResolvableBacked.apply
        case .footprint:
            guard let fp = footprintInstance,
                  var r = fp.resolvedItems.first(where: { $0.content.isSameType(as: content) }) else { return }
            r.isVisible.toggle()
            fp.apply(r)
        }
    }

    // MARK: Apply full edits / add / remove
    func apply(_ editedText: CircuitText.Resolved, for target: TextTarget) {
        switch target {
        case .symbol:
            symbolInstance.apply(editedText)
        case .footprint:
            footprintInstance?.apply(editedText)
        }
    }

    func add(_ newText: CircuitText.Instance, for target: TextTarget) {
        switch target {
        case .symbol:
            symbolInstance.add(newText)
        case .footprint:
            footprintInstance?.add(newText)
        }
    }

    func remove(_ text: CircuitText.Resolved, for target: TextTarget) {
        switch target {
        case .symbol:
            symbolInstance.remove(text)
        case .footprint:
            footprintInstance?.remove(text)
        }
    }

    // MARK: Convenience for schematic (keeps existing call sites working)
    func apply(_ editedText: CircuitText.Resolved) { apply(editedText, for: .symbol) }
    func add(_ newInstance: CircuitText.Instance)   { add(newInstance, for: .symbol) }
    func remove(_ textToRemove: CircuitText.Resolved) { remove(textToRemove, for: .symbol) }
}

extension ComponentInstance {
    func displayString(for text: CircuitText.Resolved, target: TextTarget) -> String {
        displayString(for: text.content)
    }

    func displayString(for content: CircuitTextContent) -> String {
        switch content {
        case .static(let text):
            return text
        case .componentName:
            return definition?.name ?? "???"
        case .componentReferenceDesignator:
            let prefix = definition?.referenceDesignatorPrefix ?? "REF?"
            return prefix + String(referenceDesignatorIndex)
        case .componentProperty(let definitionID, let options):
            guard let prop = displayedProperties.first(where: { $0.id == definitionID }) else { return "" }
            var parts: [String] = []
            if options.showKey { parts.append(prop.key.label) }
            let valueText = prop.value.description
            if options.showValue {
                if valueText.isEmpty {
                    if options.showUnit, !prop.unit.description.isEmpty {
                        parts.append("?\(prop.unit.description)")
                    } else {
                        parts.append("?")
                    }
                } else {
                    parts.append(valueText)
                }
            }
            if options.showUnit, !prop.unit.description.isEmpty {
                if !options.showValue || !valueText.isEmpty {
                    parts.append(prop.unit.description)
                }
            }
            return parts.joined(separator: " ")
        }
    }
}
