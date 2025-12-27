//
//  CanvasEditorManager.swift
//  CircuitPro
//
//  Created by Gemini on 8/1/25.
//

import SwiftUI
import Observation

@MainActor
@Observable
final class CanvasEditorManager {

    // MARK: - Canvas State

    let canvasStore: CanvasStore
    let textTarget: TextTarget
    let textOwnerID: UUID

    var canvasNodes: [BaseNode] {
        get { canvasStore.nodes }
        set { canvasStore.setNodes(newValue) }
    }

    var selectedElementIDs: Set<UUID> {
        get { canvasStore.selection }
        set { canvasStore.selection = newValue }
    }

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
    let graph = CanvasGraph()
    private var suppressGraphSelectionSync = false
    private var primitiveCache: [NodeID: AnyCanvasPrimitive] = [:]

    // MARK: - Layer State

    var layers: [CanvasLayer] = []
    var activeLayerId: UUID?

    // MARK: - Computed Properties

    var pins: [Pin] {
        graph.components(GraphPinComponent.self).map { $0.1.pin }
    }

    var pads: [Pad] {
        graph.components(GraphPadComponent.self).map { $0.1.pad }
    }

    var primitives: [AnyCanvasPrimitive] {
        graph.components(AnyCanvasPrimitive.self).map { $0.1 }
    }

    /// UPDATED: This now inspects the `resolvedText.content` property.
    var placedTextContents: Set<CircuitTextContent> {
        let contents = graph.components(GraphTextComponent.self).map { $0.1.resolvedText.content }
        return Set(contents)
    }

    // MARK: - State Management

    init(textTarget: TextTarget = .symbol) {
        self.canvasStore = CanvasStore()
        self.textTarget = textTarget
        self.textOwnerID = UUID()
        self.canvasStore.onNodesChanged = { [weak self] nodes in
            self?.didUpdateNodes(nodes)
        }
        self.canvasStore.onDelta = { [weak self] delta in
            self?.handleStoreDelta(delta)
        }
        self.graph.onDelta = { [weak self] delta in
            self?.handleGraphDelta(delta)
        }
    }

    private func didUpdateNodes(_ nodes: [BaseNode]) {
        elementIndexMap = Dictionary(
            uniqueKeysWithValues: nodes.enumerated().map { ($1.id, $0) }
        )
    }

    private func handleStoreDelta(_ delta: CanvasStoreDelta) {
        switch delta {
        case .selectionChanged(let selection):
            guard !suppressGraphSelectionSync else { return }
            let graphSelection = Set(selection.compactMap { id -> NodeID? in
                let nodeID = NodeID(id)
                return graph.hasAnyComponent(for: nodeID) ? nodeID : nil
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
            let graphSelectionIDs = Set(selection.map { $0.rawValue })
            let nonGraphSelection = canvasStore.selection.filter { id in
                !graph.hasAnyComponent(for: NodeID(id))
            }
            let mergedSelection = Set(nonGraphSelection).union(graphSelectionIDs)
            if canvasStore.selection != mergedSelection {
                suppressGraphSelectionSync = true
                Task { @MainActor in
                    self.canvasStore.selection = mergedSelection
                    self.suppressGraphSelectionSync = false
                }
            }
        case .componentSet(let id, let componentKey):
            if componentKey == ObjectIdentifier(AnyCanvasPrimitive.self),
               let primitive = graph.component(AnyCanvasPrimitive.self, for: id) {
                primitiveCache[id] = primitive
            }
        case .nodeRemoved(let id):
            primitiveCache.removeValue(forKey: id)
        case .nodeAdded:
            break
        case .componentRemoved(let id, let componentKey):
            if componentKey == ObjectIdentifier(AnyCanvasPrimitive.self) {
                primitiveCache.removeValue(forKey: id)
            }
        default:
            break
        }
    }

    struct ElementItem: Identifiable {
        enum Kind {
            case node(BaseNode)
            case primitive(NodeID, AnyCanvasPrimitive)
            case text(NodeID, GraphTextComponent)
            case pin(NodeID, GraphPinComponent)
            case pad(NodeID, GraphPadComponent)
        }

        let kind: Kind

        var id: UUID {
            switch kind {
            case .node(let node): return node.id
            case .primitive(let id, _): return id.rawValue
            case .text(let id, _): return id.rawValue
            case .pin(let id, _): return id.rawValue
            case .pad(let id, _): return id.rawValue
            }
        }

        var layerId: UUID? {
            switch kind {
            case .node(let node):
                return (node as? Layerable)?.layerId
            case .primitive(_, let primitive):
                return primitive.layerId
            case .text(_, let text):
                return text.layerId
            case .pin(_, let pin):
                return pin.layerId
            case .pad(_, let pad):
                return pad.layerId
            }
        }
    }

    var elementItems: [ElementItem] {
        let nodeItems = canvasNodes
            .filter { !($0 is PrimitiveNode) && !($0 is PinNode) && !($0 is PadNode) && !($0 is TextNode) }
            .map { ElementItem(kind: .node($0)) }
        let primitiveItems = graph.components(AnyCanvasPrimitive.self).map { id, primitive in
            ElementItem(kind: .primitive(id, primitive))
        }
        let textItems = graph.components(GraphTextComponent.self).map { id, text in
            ElementItem(kind: .text(id, text))
        }
        let pinItems = graph.components(GraphPinComponent.self).map { id, pin in
            ElementItem(kind: .pin(id, pin))
        }
        let padItems = graph.components(GraphPadComponent.self).map { id, pad in
            ElementItem(kind: .pad(id, pad))
        }
        return nodeItems + primitiveItems + textItems + pinItems + padItems
    }

    var singleSelectedPrimitive: (id: NodeID, primitive: AnyCanvasPrimitive)? {
        guard selectedElementIDs.count == 1, let id = selectedElementIDs.first else { return nil }
        let nodeID = NodeID(id)
        guard let primitive = graph.component(AnyCanvasPrimitive.self, for: nodeID) else { return nil }
        return (nodeID, primitive)
    }

    var singleSelectedText: (id: NodeID, text: GraphTextComponent)? {
        guard selectedElementIDs.count == 1, let id = selectedElementIDs.first else { return nil }
        let nodeID = NodeID(id)
        guard let text = graph.component(GraphTextComponent.self, for: nodeID) else { return nil }
        return (nodeID, text)
    }

    var singleSelectedPin: (id: NodeID, pin: GraphPinComponent)? {
        guard selectedElementIDs.count == 1, let id = selectedElementIDs.first else { return nil }
        let nodeID = NodeID(id)
        guard let pin = graph.component(GraphPinComponent.self, for: nodeID) else { return nil }
        return (nodeID, pin)
    }

    var singleSelectedPad: (id: NodeID, pad: GraphPadComponent)? {
        guard selectedElementIDs.count == 1, let id = selectedElementIDs.first else { return nil }
        let nodeID = NodeID(id)
        guard let pad = graph.component(GraphPadComponent.self, for: nodeID) else { return nil }
        return (nodeID, pad)
    }

    func primitiveBinding(for id: UUID) -> Binding<AnyCanvasPrimitive>? {
        let nodeID = NodeID(id)
        guard graph.component(AnyCanvasPrimitive.self, for: nodeID) != nil else { return nil }
        let fallback = primitiveCache[nodeID] ?? AnyCanvasPrimitive.line(CanvasLine(start: .zero, end: .zero, strokeWidth: 1, layerId: nil))
        return Binding(
            get: { self.graph.component(AnyCanvasPrimitive.self, for: nodeID) ?? self.primitiveCache[nodeID] ?? fallback },
            set: {
                self.primitiveCache[nodeID] = $0
                self.graph.setComponent($0, for: nodeID)
            }
        )
    }

    func textBinding(for id: UUID) -> Binding<GraphTextComponent>? {
        let nodeID = NodeID(id)
        guard graph.component(GraphTextComponent.self, for: nodeID) != nil else { return nil }
        return Binding(
            get: { self.graph.component(GraphTextComponent.self, for: nodeID)! },
            set: { newValue in
                self.setTextComponent(newValue, for: nodeID)
            }
        )
    }

    private func setTextComponent(_ component: GraphTextComponent, for id: NodeID) {
        var updated = component
        let ownerTransform = component.ownerTransform
        updated.worldPosition = component.resolvedText.relativePosition.applying(ownerTransform)
        updated.worldAnchorPosition = component.resolvedText.anchorPosition.applying(ownerTransform)
        updated.worldRotation = component.ownerRotation + component.resolvedText.cardinalRotation.radians
        if !graph.nodes.contains(id) {
            graph.addNode(id)
        }
        graph.setComponent(updated, for: id)
    }

    func pinBinding(for id: UUID) -> Binding<Pin>? {
        let nodeID = NodeID(id)
        guard let component = graph.component(GraphPinComponent.self, for: nodeID) else { return nil }
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
        guard let component = graph.component(GraphPadComponent.self, for: nodeID) else { return nil }
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
        canvasStore.setNodes([])
        canvasStore.selection = []
        selectedTool = CursorTool()
        elementIndexMap = [:]
        layers = []
        activeLayerId = nil
        primitiveCache.removeAll()
        graph.reset()
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

        let placeholder = self.resolveText(for: resolvedText.content, componentData: componentData)
        let nodeID = NodeID(GraphTextID.makeID(for: resolvedText.source, ownerID: textOwnerID, fallback: newElementID))
        let component = GraphTextComponent(
            resolvedText: resolvedText,
            displayText: placeholder,
            ownerID: textOwnerID,
            target: textTarget,
            ownerPosition: .zero,
            ownerRotation: 0,
            worldPosition: resolvedText.relativePosition,
            worldRotation: resolvedText.cardinalRotation.radians,
            worldAnchorPosition: resolvedText.anchorPosition,
            layerId: activeLayerId,
            showsAnchorGuides: false
        )

        if !graph.nodes.contains(nodeID) {
            graph.addNode(nodeID)
        }
        setTextComponent(component, for: nodeID)
    }

    /// REWRITTEN: Updates placeholder text in the graph-backed text components.
    func updateDynamicTextElements(componentData: (name: String, prefix: String, properties: [Property.Definition])) {
        for (id, component) in graph.components(GraphTextComponent.self) {
            guard !component.resolvedText.content.isStatic else { continue }
            let newText = resolveText(for: component.resolvedText.content, componentData: componentData)
            guard component.displayText != newText else { continue }
            var updated = component
            updated.displayText = newText
            setTextComponent(updated, for: id)
        }
    }

    /// UPDATED: Switches on the new `content` enum.
    func synchronizeSymbolTextWithProperties(properties: [Property.Definition]) {
        let validPropertyIDs = Set(properties.map { $0.id })

        let idsToRemove = graph.components(GraphTextComponent.self).compactMap { id, component -> NodeID? in
            guard case .componentProperty(let definitionID, _) = component.resolvedText.content else {
                return nil
            }
            return validPropertyIDs.contains(definitionID) ? nil : id
        }

        guard !idsToRemove.isEmpty else { return }
        for id in idsToRemove {
            graph.removeComponent(GraphTextComponent.self, for: id)
            if !graph.hasAnyComponent(for: id) {
                graph.removeNode(id)
            }
        }
        graph.selection.subtract(idsToRemove)
        selectedElementIDs.subtract(idsToRemove.map { $0.rawValue })
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
    func bindingForDisplayOptions(
        with id: UUID,
        componentData: (name: String, prefix: String, properties: [Property.Definition])
    ) -> Binding<TextDisplayOptions>? {
        let nodeID = NodeID(id)
        guard let component = graph.component(GraphTextComponent.self, for: nodeID),
              case .componentProperty(let definitionID, _) = component.resolvedText.content else {
            return nil
        }

        return Binding<TextDisplayOptions>(
            get: {
                // Safely extract the options from the current content enum.
                guard let current = self.graph.component(GraphTextComponent.self, for: nodeID),
                      case .componentProperty(_, let options) = current.resolvedText.content else {
                    return .default
                }
                return options
            },
            set: { newOptions in
                guard var current = self.graph.component(GraphTextComponent.self, for: nodeID) else { return }
                current.resolvedText.content = .componentProperty(definitionID: definitionID, options: newOptions)
                current.displayText = self.resolveText(for: current.resolvedText.content, componentData: componentData)
                self.setTextComponent(current, for: nodeID)
            }
        )
    }

    /// UPDATED: Switches on the new `content` enum.
    func removeTextFromSymbol(content: CircuitTextContent) {
        let idsToRemove = graph.components(GraphTextComponent.self).compactMap { id, component -> NodeID? in
            component.resolvedText.content.isSameType(as: content) ? id : nil
        }

        guard !idsToRemove.isEmpty else { return }
        for id in idsToRemove {
            graph.removeComponent(GraphTextComponent.self, for: id)
            if !graph.hasAnyComponent(for: id) {
                graph.removeNode(id)
            }
        }
        graph.selection.subtract(idsToRemove)
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
        case (.static, .static): return true // Note: You might want to compare text for static
        case (.componentName, .componentName): return true
        case (.componentReferenceDesignator, .componentReferenceDesignator): return true
        case (.componentProperty(let id1, _), .componentProperty(let id2, _)): return id1 == id2
        default: return false
        }
    }
}
