//
//  ProjectManager.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/5/25.
//

import SwiftUI
import Observation

/// A temporary struct that pairs the resolved data model with its generated display string,
/// for use during a single canvas rebuild operation.
struct RenderableText {
    let model: CircuitText.Resolved
    let text: String
}

@Observable
final class ProjectManager {
    
    var project: CircuitProject
    var selectedDesign: CircuitDesign?
    var selectedNodeIDs: Set<UUID> = []
    var canvasNodes: [BaseNode] = []
    var selectedNetIDs: Set<UUID> = []
    
    var schematicGraph = WireGraph()
    
    init(
        project: CircuitProject,
        selectedDesign: CircuitDesign? = nil
    ) {
        self.project        = project
        self.selectedDesign = selectedDesign
    }
    
    var componentInstances: [ComponentInstance] {
        get { selectedDesign?.componentInstances ?? [] }
        set { selectedDesign?.componentInstances = newValue }
    }
    
    func persistSchematicGraph() {
        guard selectedDesign != nil else { return }
        selectedDesign?.wires = schematicGraph.toWires()
    }
    
    // MARK: - Property Management (Unchanged)
    
    func updateProperty(for component: ComponentInstance, with editedProperty: Property.Resolved) {
        component.apply(editedProperty)
        rebuildCanvasNodes()
    }
    
    func addProperty(_ newProperty: Property.Instance, to component: ComponentInstance) {
        component.add(newProperty)
        rebuildCanvasNodes()
    }
    
    func removeProperty(_ propertyToRemove: Property.Resolved, from component: ComponentInstance) {
        component.remove(propertyToRemove)
        rebuildCanvasNodes()
    }

    // MARK: - Text Management (REWRITTEN)
    
    func toggleDynamicTextVisibility(for component: ComponentInstance, content: CircuitTextContent) {
        // The search logic now compares the `content` property.
        if let textToToggle = component.symbolInstance.resolvedItems.first(where: { $0.content.isSameType(as: content) }) {
            var editedText = textToToggle
            editedText.isVisible.toggle()
            updateText(for: component, with: editedText)
        } else {
            // This logic is for adding a text override for the first time if one doesn't exist.
            let existingTextPositions = component.symbolInstance.resolvedItems.map(\.relativePosition)
            let lowestY = existingTextPositions.map(\.y).min() ?? -20
            let newPosition = CGPoint(x: 0, y: lowestY - 10)
            
            // Note: This creates an ad-hoc instance.
            let newTextInstance = CircuitText.Instance(
                content: content,
                relativePosition: newPosition,
                anchorPosition: newPosition
            )
            addText(newTextInstance, to: component)
        }
    }
    
    func togglePropertyVisibility(for component: ComponentInstance, property: Property.Resolved) {
        guard case .definition(let propertyDef) = property.source else {
            print("Error: Visibility can only be toggled for definition-based properties.")
            return
        }
        
        // Find the default options from the SymbolDefinition if they exist.
        let defaultOptions = component.definition?.symbol?.textDefinitions
            .first(where: { $0.content.isSameType(as: .componentProperty(definitionID: propertyDef.id, options: .default)) })?
            .content.displayOptions ?? .default
        
        let contentToToggle = CircuitTextContent.componentProperty(definitionID: propertyDef.id, options: defaultOptions)
        toggleDynamicTextVisibility(for: component, content: contentToToggle)
    }

    // MARK: - Other Component Actions
    
    func updateReferenceDesignator(for component: ComponentInstance, newIndex: Int) {
        component.referenceDesignatorIndex = newIndex
        rebuildCanvasNodes()
    }
    
    // MARK: - Canvas and Graph Management (REWRITTEN)
    
    private func makeGraph(from design: CircuitDesign) -> WireGraph {
        let newGraph = WireGraph()
        newGraph.build(from: design.wires)
        
        for inst in design.componentInstances {
            guard let symbolDef = inst.definition?.symbol else { continue }
            newGraph.syncPins(for: inst.symbolInstance, of: symbolDef, ownerID: inst.id)
        }
        return newGraph
    }
    
    /// Prepares render-ready text models by pairing them with their generated display strings.
    private func generateRenderableTexts(for inst: ComponentInstance) -> [RenderableText] {
        return inst.symbolInstance.resolvedItems.map { resolvedModel in
            let displayString = self.generateString(for: resolvedModel, component: inst)
            return RenderableText(model: resolvedModel, text: displayString)
        }
    }
    
    func rebuildCanvasNodes() {
        guard let design = selectedDesign else {
            self.canvasNodes = []
            self.schematicGraph = WireGraph()
            return
        }
        
        let newGraph = self.makeGraph(from: design)
        self.schematicGraph = newGraph
        
        let symbolNodes: [SymbolNode] = design.componentInstances.compactMap { inst -> SymbolNode? in
            guard inst.symbolInstance.definition != nil else { return nil }
            let renderableTexts = self.generateRenderableTexts(for: inst)
            
            // IMPORTANT: The SymbolNode initializer will need to be updated to accept `[RenderableText]`.
            // It is now responsible for creating TextNodes and passing the correct `text` string to them.
            return SymbolNode(id: inst.id, instance: inst.symbolInstance, renderableTexts: renderableTexts, graph: self.schematicGraph)
        }
        let graphNode = SchematicGraphNode(graph: self.schematicGraph)
        graphNode.syncChildNodesFromModel()
        
        self.canvasNodes = symbolNodes + [graphNode]
    }

    /// NOTE: This function's `resolvedTexts` parameter will need to change signature
    /// to what's shown below in the SymbolNode call.
    func upsertSymbolNode(for inst: ComponentInstance) {
        guard inst.symbolInstance.definition != nil else { return }
        
        let renderableTexts = self.generateRenderableTexts(for: inst)
        
        guard let node = SymbolNode(id: inst.id, instance: inst.symbolInstance, renderableTexts: renderableTexts, graph: self.schematicGraph) else { return }
        
        if let idx = canvasNodes.firstIndex(where: { $0.id == inst.id }) {
            canvasNodes[idx] = node
        } else if let graphIndex = canvasNodes.firstIndex(where: { $0 is SchematicGraphNode }) {
            canvasNodes.insert(node, at: graphIndex)
        } else {
            let graphNode = SchematicGraphNode(graph: self.schematicGraph)
            graphNode.syncChildNodesFromModel()
            canvasNodes = [node, graphNode]
        }
    }
    
    func updateText(for component: ComponentInstance, with editedText: CircuitText.Resolved) {
        component.apply(editedText)
        rebuildCanvasNodes()
    }

    func addText(_ newText: CircuitText.Instance, to component: ComponentInstance) {
        component.add(newText)
        rebuildCanvasNodes()
    }

    func removeText(_ textToRemove: CircuitText.Resolved, from component: ComponentInstance) {
        component.remove(textToRemove)
        rebuildCanvasNodes()
    }
    
    /// REWRITTEN: Generates a display string from the resolved model and its component context.
    func generateString(for resolvedText: CircuitText.Resolved, component: ComponentInstance) -> String {
        switch resolvedText.content {
        case .static(let text):
            return text
            
        case .componentName:
            return component.definition?.name ?? "???"
            
        case .componentReferenceDesignator:
            return (component.definition?.referenceDesignatorPrefix ?? "REF?") + component.referenceDesignatorIndex.description
            
        case .componentProperty(let definitionID, let options):
            guard let property = component.displayedProperties.first(where: { $0.id == definitionID }) else {
                return ""
            }
            
            var parts: [String] = []
            if options.showKey { parts.append(property.key.label) }
            if options.showValue { parts.append(property.value.description) }
            if options.showUnit, !property.unit.description.isEmpty { parts.append(property.unit.description) }
            return parts.joined(separator: " ")
        }
    }
}


extension ComponentInstance {
    // These methods remain valid as they interact with the @ResolvableDestination macro.
    func apply(_ editedText: CircuitText.Resolved) {
        symbolInstance.apply(editedText)
    }

    func add(_ newInstance: CircuitText.Instance) {
        symbolInstance.add(newInstance)
    }

    func remove(_ textToRemove: CircuitText.Resolved) {
        symbolInstance.remove(textToRemove)
    }
}

// Add this helper to your CircuitTextContent enum to simplify checking.
extension CircuitTextContent {

    
    var displayOptions: TextDisplayOptions? {
        if case .componentProperty(_, let options) = self {
            return options
        }
        return nil
    }
}
