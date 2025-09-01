//
//  ProjectManager.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/5/25.
//

import SwiftUI
import Observation

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
    
    // MARK: - New, Simplified Property Management
    
    /// Updates a component's property using an edited `Resolved` model.
    /// This method delegates the entire update operation to the component itself.
    func updateProperty(for component: ComponentInstance, with editedProperty: Property.Resolved) {
        component.apply(editedProperty)
        rebuildCanvasNodes()
    }
    
    /// Adds a new, ad-hoc property directly to a component instance.
    func addProperty(_ newProperty: Property.Instance, to component: ComponentInstance) {
        component.add(newProperty)
        rebuildCanvasNodes()
    }
    
    /// Removes a property from a component.
    /// This will either delete an ad-hoc instance or revert a definition-based property to its default.
    func removeProperty(_ propertyToRemove: Property.Resolved, from component: ComponentInstance) {
        component.remove(propertyToRemove)
        rebuildCanvasNodes()
    }

    // MARK: - Text Management (Remains for now, will be refactored next)
    
    func toggleDynamicTextVisibility(for component: ComponentInstance, source: TextSource) {
        // NOTE: This logic should eventually be moved to a `TextBacked` conformance
        // on SymbolInstance, just like we did for Property.
        guard let definition = component.definition,
              let symbol = definition.symbol else { return }
        
        if let textDefinition = symbol.textDefinitions.first(where: { $0.contentSource == source }) {
            if let overrideIndex = component.symbolInstance.textOverrides.firstIndex(where: { $0.definitionID == textDefinition.id }) {
                let currentVisibility = component.symbolInstance.textOverrides[overrideIndex].isVisible ?? true
                component.symbolInstance.textOverrides[overrideIndex].isVisible = !currentVisibility
            } else {
                let newOverride = CircuitText.Override(definitionID: textDefinition.id, isVisible: false)
                component.symbolInstance.textOverrides.append(newOverride)
            }
        } else if let instanceIndex = component.symbolInstance.textInstances.firstIndex(where: { $0.contentSource == source }) {
            let currentVisibility = component.symbolInstance.textInstances[instanceIndex].isVisible
            component.symbolInstance.textInstances[instanceIndex].isVisible = !currentVisibility
        } else {
            let existingTextPositions = component.symbolInstance.textInstances.map(\.relativePosition)
            let lowestY = existingTextPositions.map(\.y).min() ?? -20
            let newPosition = CGPoint(x: 0, y: lowestY - 10)
            
            let newTextInstance = CircuitText.Instance(id: UUID(), contentSource: source, relativePosition: newPosition, anchorPosition: newPosition, font: .init(font: .systemFont(ofSize: 12)), color: .init(color: .black), anchor: .leading, alignment: .left, cardinalRotation: .east, isVisible: true)
            component.symbolInstance.textInstances.append(newTextInstance)
        }
        
        rebuildCanvasNodes()
    }
    
    func togglePropertyVisibility(for component: ComponentInstance, property: Property.Resolved) {
        guard case .definition(let propertyDef) = property.source else {
            print("Error: Visibility can only be toggled for definition-based properties.")
            return
        }
        // This links a property to its corresponding text element on the canvas.
        let source = TextSource.componentProperty(definitionID: propertyDef.id)
        toggleDynamicTextVisibility(for: component, source: source)
    }

    // MARK: - Other Component Actions
    
    func updateReferenceDesignator(for component: ComponentInstance, newIndex: Int) {
        component.referenceDesignatorIndex = newIndex
        rebuildCanvasNodes()
    }
    
    // MARK: - Canvas and Graph Management
    
    private func makeGraph(from design: CircuitDesign) -> WireGraph {
        let newGraph = WireGraph()
        newGraph.build(from: design.wires)
        
        for inst in design.componentInstances {
            guard let symbolDef = inst.definition?.symbol else { continue }
            newGraph.syncPins(for: inst.symbolInstance, of: symbolDef, ownerID: inst.id)
        }
        return newGraph
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
            
            // NOTE: This will later become `inst.symbolInstance.resolvedTexts`
            let resolvedTexts = TextResolver.resolve(for: inst)
            
            return SymbolNode(id: inst.id, instance: inst.symbolInstance, resolvedTexts: resolvedTexts, graph: self.schematicGraph)
        }
        
        let graphNode = SchematicGraphNode(graph: self.schematicGraph)
        graphNode.syncChildNodesFromModel()
        
        self.canvasNodes = symbolNodes + [graphNode]
    }
    
    func upsertSymbolNode(for inst: ComponentInstance) {
        guard inst.symbolInstance.definition != nil else { return }
        
        guard let node = SymbolNode(id: inst.id, instance: inst.symbolInstance, resolvedTexts: TextResolver.resolve(for: inst), graph: self.schematicGraph) else { return }
        
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
}
