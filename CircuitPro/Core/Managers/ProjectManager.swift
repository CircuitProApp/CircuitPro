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
    
    func toggleDynamicTextVisibility(for component: ComponentInstance, source: TextSource) {
        guard let definition = component.definition,
              let symbol = definition.symbol else { return }
        
        // Case 1: The text is defined in the symbol definition. We toggle its visibility via an override.
        if let textDefinition = symbol.textDefinitions.first(where: { $0.contentSource == source }) {
            if let overrideIndex = component.symbolInstance.textOverrides.firstIndex(where: { $0.definitionID == textDefinition.id }) {
                let currentVisibility = component.symbolInstance.textOverrides[overrideIndex].isVisible ?? true
                component.symbolInstance.textOverrides[overrideIndex].isVisible = !currentVisibility
            } else {
                let newOverride = CircuitText.Override(definitionID: textDefinition.id, isVisible: false)
                component.symbolInstance.textOverrides.append(newOverride)
            }
            
            // Case 2: The text exists as a user-added instance. We toggle its visibility.
        } else if let instanceIndex = component.symbolInstance.textInstances.firstIndex(where: { $0.contentSource == source }) {
            let currentVisibility = component.symbolInstance.textInstances[instanceIndex].isVisible
            component.symbolInstance.textInstances[instanceIndex].isVisible = !currentVisibility
            
            // Case 3: The text is not displayed at all. We create a new instance to show it.
        } else {
            let existingTextPositions = component.symbolInstance.textInstances.map(\.relativePosition)
            let lowestY = existingTextPositions.map(\.y).min() ?? -20
            let newPosition = CGPoint(x: 0, y: lowestY - 10)
            
            let newTextInstance = CircuitText.Instance(
                id: UUID(),
                contentSource: source,
                relativePosition: newPosition,
                anchorPosition: newPosition,
                font: .init(font: .systemFont(ofSize: 12)),
                color: .init(color: .black),
                anchor: .leading,
                alignment: .left,
                cardinalRotation: .east,
                isVisible: true
            )
            component.symbolInstance.textInstances.append(newTextInstance)
        }
        
        rebuildCanvasNodes()
    }
    
    func togglePropertyVisibility(for component: ComponentInstance, property: Property.Resolved) {
        guard case .definition(let propertyDefID) = property.source else {
            print("Error: Visibility can only be toggled for definition-based properties.")
            return
        }
        let source = TextSource.componentProperty(definitionID: propertyDefID.id)
        toggleDynamicTextVisibility(for: component, source: source)
    }
    
    func updateProperty(for component: ComponentInstance, with editedProperty: Property.Resolved) {
        guard case .definition(let definitionID) = editedProperty.source else {
            print("not found")
            return }
        print(definitionID)
        // Use the new helper to get the original property
        guard let originalProperty = component.displayedProperties.first(where: { $0.id == editedProperty.id }) else { return }
        
        if originalProperty.value != editedProperty.value {
            component.update(definitionID: definitionID.id, value: editedProperty.value)
        }
        if originalProperty.unit.prefix != editedProperty.unit.prefix {
            component.update(definitionID: definitionID.id, prefix: editedProperty.unit.prefix)
        }
        rebuildCanvasNodes()
    }
    
    func updateReferenceDesignator(for component: ComponentInstance, newIndex: Int) {
        component.referenceDesignatorIndex = newIndex
        rebuildCanvasNodes()
    }
    
    private func makeGraph(from design: CircuitDesign) -> WireGraph {
        let newGraph = WireGraph()
        newGraph.build(from: design.wires)
        
        // Iterate directly over the hydrated instances.
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
        
        // --- REFACTORED LOGIC ---
        let symbolNodes: [SymbolNode] = design.componentInstances.compactMap { inst -> SymbolNode? in
            
            // The guard is now simpler and more direct.
            // We just need the definition on the symbol instance itself.
            guard let symbolDefinition = inst.symbolInstance.definition else {
                return nil
            }
            
            let resolvedTexts = TextResolver.resolve(for: inst)
            
            return SymbolNode(
                id: inst.id,
                instance: inst.symbolInstance,
                resolvedTexts: resolvedTexts,
                graph: self.schematicGraph
            )
        }
        
        let graphNode = SchematicGraphNode(graph: self.schematicGraph)
        graphNode.syncChildNodesFromModel()
        
        self.canvasNodes = symbolNodes + [graphNode]
    }
    
}

extension ProjectManager {
    func upsertSymbolNode(for inst: ComponentInstance) {
        // Must be hydrated or we can't render the symbol
        guard inst.symbolInstance.definition != nil else { return }
        
        // Build the node. If your SymbolNode init is failable, unwrap here.
        guard let node = SymbolNode(
            id: inst.id,
            instance: inst.symbolInstance,
            resolvedTexts: TextResolver.resolve(for: inst),
            graph: self.schematicGraph
        ) else {
            // If the initializer is NOT failable in your project,
            // remove `guard let` and the `?` on the type above.
            return
        }
        
        // Replace if symbol already exists
        if let idx = canvasNodes.firstIndex(where: { $0.id == inst.id }) {
            canvasNodes[idx] = node // or `node as BaseNode` if the compiler asks
            return
        }
        
        // Insert before the graph node if present, otherwise create a graph node
        if let graphIndex = canvasNodes.firstIndex(where: { $0 is SchematicGraphNode }) {
            canvasNodes.insert(node, at: graphIndex) // or `node as BaseNode`
        } else {
            let graphNode = SchematicGraphNode(graph: self.schematicGraph)
            graphNode.syncChildNodesFromModel()
            canvasNodes = [node, graphNode] // both are BaseNode
        }
    }
}


