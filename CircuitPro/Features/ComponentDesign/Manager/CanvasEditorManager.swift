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

    let canvasStore: CanvasStore
    let textTarget: TextTarget
    let textOwnerID: UUID

    var selectedElementIDs: Set<UUID> {
        get { canvasStore.selection }
        set { canvasStore.selection = newValue }
    }

    var selectedTool: CanvasTool = CursorTool()
    let graph = CanvasGraph()
    private var suppressGraphSelectionSync = false
    private var primitiveCache: [NodeID: AnyCanvasPrimitive] = [:]

    // MARK: - Layer State

    var layers: [CanvasLayer] = []
    var activeLayerId: UUID?

    // MARK: - Computed Properties

    var pins: [Pin] {
        graph.components(CanvasPin.self).map { $0.1.pin }
    }

    var pads: [Pad] {
        graph.components(CanvasPad.self).map { $0.1.pad }
    }

    var primitives: [AnyCanvasPrimitive] {
        graph.components(CanvasPrimitiveElement.self).map { $0.1.primitive }
    }

    /// UPDATED: This now inspects the `resolvedText.content` property.
    var placedTextContents: Set<CircuitTextContent> {
        let contents = graph.components(CanvasText.self).map { $0.1.resolvedText.content }
        return Set(contents)
    }

    // MARK: - State Management

    init(textTarget: TextTarget = .symbol) {
        self.canvasStore = CanvasStore()
        self.textTarget = textTarget
        self.textOwnerID = UUID()
        self.canvasStore.onDelta = { [weak self] delta in
            self?.handleStoreDelta(delta)
        }
        self.graph.onDelta = { [weak self] delta in
            self?.handleGraphDelta(delta)
        }
    }

    private func handleStoreDelta(_ delta: CanvasStoreDelta) {
        switch delta {
        case .selectionChanged(let selection):
            guard !suppressGraphSelectionSync else { return }
            let graphSelection = Set(
                selection.compactMap { id -> GraphElementID? in
                    let nodeID = NodeID(id)
                    return graph.hasAnyComponent(for: nodeID) ? .node(nodeID) : nil
                })
            if graph.selection != graphSelection {
                graph.selection = graphSelection
            }
        default:
            break
        }
    }

    private func handleGraphDelta(_ delta: UnifiedGraphDelta) {
        switch delta {
        case .selectionChanged(let selection):
            let graphSelectionIDs = Set(selection.compactMap { $0.nodeID?.rawValue })
            if canvasStore.selection != graphSelectionIDs {
                suppressGraphSelectionSync = true
                Task { @MainActor in
                    self.canvasStore.selection = graphSelectionIDs
                    self.suppressGraphSelectionSync = false
                }
            }
        case .nodeComponentSet(let id, let componentKey):
            if componentKey == ObjectIdentifier(CanvasPrimitiveElement.self),
                let component = graph.component(CanvasPrimitiveElement.self, for: id)
            {
                primitiveCache[id] = component.primitive
            }
            canvasStore.invalidate()
        case .nodeRemoved(let id):
            primitiveCache.removeValue(forKey: id)
            canvasStore.invalidate()
        case .nodeComponentRemoved(let id, let componentKey):
            if componentKey == ObjectIdentifier(CanvasPrimitiveElement.self) {
                primitiveCache.removeValue(forKey: id)
            }
            canvasStore.invalidate()
        case .edgeAdded,
            .edgeRemoved,
            .nodeAdded,
            .edgeComponentSet,
            .edgeComponentRemoved:
            canvasStore.invalidate()
        default:
            break
        }
    }

    struct ElementItem: Identifiable {
        enum Kind {
            case primitive(NodeID, CanvasPrimitiveElement)
            case text(NodeID, CanvasText)
            case pin(NodeID, CanvasPin)
            case pad(NodeID, CanvasPad)
        }

        let kind: Kind

        var id: UUID {
            switch kind {
            case .primitive(let id, _): return id.rawValue
            case .text(let id, _): return id.rawValue
            case .pin(let id, _): return id.rawValue
            case .pad(let id, _): return id.rawValue
            }
        }

        var layerId: UUID? {
            switch kind {
            case .primitive(_, let primitive):
                return primitive.layerId
            case .text(_, let text):
                return text.layerId
            case .pin(_, let pin):
                return nil
            case .pad(_, let pad):
                return pad.layerId
            }
        }
    }

    var elementItems: [ElementItem] {
        let primitiveItems = graph.components(CanvasPrimitiveElement.self).map { id, primitive in
            ElementItem(kind: .primitive(id, primitive))
        }
        let textItems = graph.components(CanvasText.self).map { id, text in
            ElementItem(kind: .text(id, text))
        }
        let pinItems = graph.components(CanvasPin.self).map { id, pin in
            ElementItem(kind: .pin(id, pin))
        }
        let padItems = graph.components(CanvasPad.self).map { id, pad in
            ElementItem(kind: .pad(id, pad))
        }
        return primitiveItems + textItems + pinItems + padItems
    }

    var singleSelectedPrimitive: (id: NodeID, primitive: CanvasPrimitiveElement)? {
        guard selectedElementIDs.count == 1, let id = selectedElementIDs.first else { return nil }
        let nodeID = NodeID(id)
        guard let primitive = graph.component(CanvasPrimitiveElement.self, for: nodeID) else {
            return nil
        }
        return (nodeID, primitive)
    }

    var singleSelectedText: (id: NodeID, text: CanvasText)? {
        guard selectedElementIDs.count == 1, let id = selectedElementIDs.first else { return nil }
        let nodeID = NodeID(id)
        guard let text = graph.component(CanvasText.self, for: nodeID) else { return nil }
        return (nodeID, text)
    }

    var singleSelectedPin: (id: NodeID, pin: CanvasPin)? {
        guard selectedElementIDs.count == 1, let id = selectedElementIDs.first else { return nil }
        let nodeID = NodeID(id)
        guard let pin = graph.component(CanvasPin.self, for: nodeID) else { return nil }
        return (nodeID, pin)
    }

    var singleSelectedPad: (id: NodeID, pad: CanvasPad)? {
        guard selectedElementIDs.count == 1, let id = selectedElementIDs.first else { return nil }
        let nodeID = NodeID(id)
        guard let pad = graph.component(CanvasPad.self, for: nodeID) else { return nil }
        return (nodeID, pad)
    }

    func primitiveBinding(for id: UUID) -> Binding<AnyCanvasPrimitive>? {
        let nodeID = NodeID(id)
        guard let component = graph.component(CanvasPrimitiveElement.self, for: nodeID) else {
            return nil
        }
        return Binding(
            get: { component.primitive },
            set: {
                var updated = component
                updated.primitive = $0
                self.primitiveCache[nodeID] = $0
                self.graph.setComponent(updated, for: nodeID)
            }
        )
    }

    func textBinding(for id: UUID) -> Binding<CanvasText>? {
        let nodeID = NodeID(id)
        guard let component = graph.component(CanvasText.self, for: nodeID) else { return nil }
        return Binding(
            get: { component },
            set: { newValue in
                self.setTextComponent(newValue, for: nodeID)
            }
        )
    }

    private func setTextComponent(_ component: CanvasText, for id: NodeID) {
        if !graph.nodes.contains(id) {
            graph.addNode(id)
        }
        graph.setComponent(component, for: id)
    }

    func pinBinding(for id: UUID) -> Binding<Pin>? {
        let nodeID = NodeID(id)
        guard let component = graph.component(CanvasPin.self, for: nodeID) else { return nil }
        return Binding(
            get: { component.pin },
            set: { newPin in
                var updated = component
                updated.pin = newPin
                self.graph.setComponent(updated, for: nodeID)
            }
        )
    }

    func padBinding(for id: UUID) -> Binding<Pad>? {
        let nodeID = NodeID(id)
        guard let component = graph.component(CanvasPad.self, for: nodeID) else {
            return nil
        }
        return Binding(
            get: { component.pad },
            set: { newPad in
                var updated = component
                updated.pad = newPad
                self.graph.setComponent(updated, for: nodeID)
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
        canvasStore.selection = []
        canvasStore.invalidate()
        selectedTool = CursorTool()
        layers = []
        activeLayerId = nil
        primitiveCache.removeAll()
        graph.reset()
    }

    // Canvas items should live in the graph; no environment renderables.
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
        let nodeID = NodeID(
            GraphTextID.makeID(
                for: resolvedText.source, ownerID: textOwnerID, fallback: newElementID))
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

        if !graph.nodes.contains(nodeID) {
            graph.addNode(nodeID)
        }
        setTextComponent(component, for: nodeID)
    }

    /// REWRITTEN: Updates placeholder text in the graph-backed text components.
    func updateDynamicTextElements(
        componentData: (name: String, prefix: String, properties: [Property.Definition])
    ) {
        for (id, component) in graph.components(CanvasText.self) {
            guard !component.resolvedText.content.isStatic else { continue }
            let newText = resolveText(
                for: component.resolvedText.content, componentData: componentData)
            guard component.displayText != newText else { continue }
            var updated = component
            updated.displayText = newText
            setTextComponent(updated, for: id)
        }
    }

    /// UPDATED: Switches on the new `content` enum.
    func synchronizeSymbolTextWithProperties(properties: [Property.Definition]) {
        let validPropertyIDs = Set(properties.map { $0.id })

        let idsToRemove = graph.components(CanvasText.self).compactMap { id, component -> NodeID? in
            guard case .componentProperty(let definitionID, _) = component.resolvedText.content
            else {
                return nil
            }
            return validPropertyIDs.contains(definitionID) ? nil : id
        }

        guard !idsToRemove.isEmpty else { return }
        for id in idsToRemove {
            graph.removeComponent(CanvasText.self, for: id)
            if !graph.hasAnyComponent(for: id) {
                graph.removeNode(id)
            }
        }
        graph.selection.subtract(idsToRemove.map { .node($0) })
        selectedElementIDs.subtract(idsToRemove.map { $0.rawValue })
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
        let nodeID = NodeID(id)
        guard let component = graph.component(CanvasText.self, for: nodeID),
            case .componentProperty(let definitionID, _) = component.resolvedText.content
        else {
            return nil
        }

        return Binding<TextDisplayOptions>(
            get: {
                // Safely extract the options from the current content enum.
                guard let current = self.graph.component(CanvasText.self, for: nodeID),
                    case .componentProperty(_, let options) = current.resolvedText.content
                else {
                    return .default
                }
                return options
            },
            set: { newOptions in
                guard let current = self.graph.component(CanvasText.self, for: nodeID) else {
                    return
                }
                var updated = current
                updated.resolvedText.content = .componentProperty(
                    definitionID: definitionID, options: newOptions)
                updated.displayText = self.resolveText(
                    for: updated.resolvedText.content, componentData: componentData)
                self.setTextComponent(updated, for: nodeID)
            }
        )
    }

    /// UPDATED: Switches on the new `content` enum.
    func removeTextFromSymbol(content: CircuitTextContent) {
        let idsToRemove = graph.components(CanvasText.self).compactMap { id, component -> NodeID? in
            component.resolvedText.content.isSameType(as: content) ? id : nil
        }

        guard !idsToRemove.isEmpty else { return }
        for id in idsToRemove {
            graph.removeComponent(CanvasText.self, for: id)
            if !graph.hasAnyComponent(for: id) {
                graph.removeNode(id)
            }
        }
        graph.selection.subtract(idsToRemove.map { .node($0) })
        selectedElementIDs.subtract(idsToRemove.map { $0.rawValue })
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
