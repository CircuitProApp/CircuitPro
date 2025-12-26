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
    private var suppressPrimitiveRemoval = false
    private var suppressGraphSelectionSync = false
    private var primitiveCache: [NodeID: AnyCanvasPrimitive] = [:]
    private var graphNodeProxyIDs: Set<NodeID> = []

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

    var primitives: [AnyCanvasPrimitive] {
        graph.components(AnyCanvasPrimitive.self).map { $0.1 }
    }

    /// UPDATED: This now inspects the `resolvedText.content` property.
    var placedTextContents: Set<CircuitTextContent> {
        let contents = canvasNodes.compactMap { ($0 as? TextNode)?.resolvedText.content }
        return Set(contents)
    }

    // MARK: - State Management

    init() {
        self.canvasStore = CanvasStore()
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
        let currentNodeIDs = Set(nodes.map(\.id))
        displayTextMap = displayTextMap.filter { currentNodeIDs.contains($0.key) }
        syncGraphNodeProxies(from: nodes)
    }

    private func handleStoreDelta(_ delta: CanvasStoreDelta) {
        switch delta {
        case .reset(let nodes):
            syncGraph(from: nodes)
            removePrimitiveNodes(from: nodes)
            syncPrimitiveCacheFromGraph()
        case .nodesAdded(let nodes):
            addGraphPrimitives(from: nodes)
            removePrimitiveNodes(from: nodes)
            syncPrimitiveCacheFromGraph()
        case .nodesRemoved(let ids):
            for id in ids {
                graph.removeNode(NodeID(id))
            }
        case .selectionChanged(let selection):
            guard !suppressGraphSelectionSync else { return }
            let graphSelection = Set(selection.compactMap { id -> NodeID? in
                let nodeID = NodeID(id)
                return graph.hasAnyComponent(for: nodeID) ? nodeID : nil
            })
            if graph.selection != graphSelection {
                graph.selection = graphSelection
            }
        }
    }

    private func handleGraphDelta(_ delta: UnifiedGraphDelta) {
        switch delta {
        case .selectionChanged(let selection):
            let selectionIDs = Set(selection.map { $0.rawValue })
            if canvasStore.selection != selectionIDs {
                suppressGraphSelectionSync = true
                Task { @MainActor in
                    self.canvasStore.selection = selectionIDs
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

    private func syncPrimitiveCacheFromGraph() {
        primitiveCache = Dictionary(
            uniqueKeysWithValues: graph.components(AnyCanvasPrimitive.self).map { ($0.0, $0.1) }
        )
    }

    private func syncGraph(from nodes: [BaseNode]) {
        graph.reset()
        addGraphPrimitives(from: nodes)
    }

    private func addGraphPrimitives(from nodes: [BaseNode]) {
        for node in nodes {
            guard let primitiveNode = node as? PrimitiveNode else { continue }
            let graphID = NodeID(primitiveNode.id)
            graph.addNode(graphID)
            graph.setComponent(primitiveNode.primitive, for: graphID)
        }
    }

    private func removePrimitiveNodes(from nodes: [BaseNode]) {
        guard !suppressPrimitiveRemoval else { return }
        let primitiveIDs = Set(nodes.compactMap { ($0 as? PrimitiveNode)?.id })
        guard !primitiveIDs.isEmpty else { return }
        suppressPrimitiveRemoval = true
        canvasStore.removeNodes(ids: primitiveIDs, emitDelta: false)
        suppressPrimitiveRemoval = false
    }

    struct ElementItem: Identifiable {
        enum Kind {
            case node(BaseNode)
            case primitive(NodeID, AnyCanvasPrimitive)
        }

        let kind: Kind

        var id: UUID {
            switch kind {
            case .node(let node): return node.id
            case .primitive(let id, _): return id.rawValue
            }
        }

        var layerId: UUID? {
            switch kind {
            case .node(let node):
                return (node as? Layerable)?.layerId
            case .primitive(_, let primitive):
                return primitive.layerId
            }
        }
    }

    var elementItems: [ElementItem] {
        let nodeItems = canvasNodes
            .filter { !($0 is PrimitiveNode) }
            .map { ElementItem(kind: .node($0)) }
        let primitiveItems = graph.components(AnyCanvasPrimitive.self).map { id, primitive in
            ElementItem(kind: .primitive(id, primitive))
        }
        return nodeItems + primitiveItems
    }

    var singleSelectedPrimitive: (id: NodeID, primitive: AnyCanvasPrimitive)? {
        guard selectedElementIDs.count == 1, let id = selectedElementIDs.first else { return nil }
        let nodeID = NodeID(id)
        guard let primitive = graph.component(AnyCanvasPrimitive.self, for: nodeID) else { return nil }
        return (nodeID, primitive)
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
        displayTextMap = [:] // Reset the new map
        layers = []
        activeLayerId = nil
        graph.reset()
    }

    private func syncGraphNodeProxies(from nodes: [BaseNode]) {
        let selectableNodes = nodes.flattened().filter { $0.isSelectable }
        let newIDs = Set(selectableNodes.map { NodeID($0.id) })

        let removedIDs = graphNodeProxyIDs.subtracting(newIDs)
        for id in removedIDs {
            graph.removeComponent(GraphNodeComponent.self, for: id)
            if !graph.hasAnyComponent(for: id) {
                graph.removeNode(id)
            }
        }

        for node in selectableNodes {
            let nodeID = NodeID(node.id)
            if !graph.nodes.contains(nodeID) {
                graph.addNode(nodeID)
            }
            let kind: GraphNodeComponent.Kind = (node is TextNode) ? .text : .node
            graph.setComponent(GraphNodeComponent(kind: kind), for: nodeID)
        }

        graphNodeProxyIDs = newIDs
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

        // Pass the generated `placeholder` string to the TextNode initializer.
        let newNode = TextNode(id: newElementID, resolvedText: resolvedText, text: placeholder)

        canvasStore.addNode(newNode)
    }

    /// REWRITTEN: Updates placeholder text in the `displayTextMap`.
    func updateDynamicTextElements(componentData: (name: String, prefix: String, properties: [Property.Definition])) {
        for node in canvasNodes {
            guard let textNode = node as? TextNode else { continue }
            refreshDisplayText(for: textNode, componentData: componentData)
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
        let remainingNodes = canvasStore.nodes.filter { !idsToRemove.contains($0.id) }
        canvasStore.setNodes(remainingNodes)
        selectedElementIDs.subtract(idsToRemove)
        // displayTextMap will be pruned by didUpdateNodes.
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
                self.refreshDisplayText(for: textNode, componentData: componentData)
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
        let remainingNodes = canvasStore.nodes.filter { !idsToRemove.contains($0.id) }
        canvasStore.setNodes(remainingNodes)
        selectedElementIDs.subtract(idsToRemove)
    }

    private func refreshDisplayText(
        for textNode: TextNode,
        componentData: (name: String, prefix: String, properties: [Property.Definition])
    ) {
        let newText = resolveText(for: textNode.resolvedText.content, componentData: componentData)
        if textNode.displayText != newText {
            textNode.displayText = newText
        }
        if displayTextMap[textNode.id] != newText {
            displayTextMap[textNode.id] = newText
        }
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
