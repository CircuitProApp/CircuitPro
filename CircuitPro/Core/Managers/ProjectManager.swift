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
    
    // --- MODIFIED: Separate node arrays for each editor ---
    var schematicCanvasNodes: [BaseNode] = []
    var layoutCanvasNodes: [BaseNode] = []
    // ---
    
    var selectedNetIDs: Set<UUID> = []
    
    var selectedEditor: EditorType = .schematic
    
    var schematicGraph = WireGraph()
    
    init(
        project: CircuitProject,
        selectedDesign: CircuitDesign? = nil
    ) {
        self.project        = project
        self.selectedDesign = selectedDesign
    }
    
    // --- ADDED: Computed property for the active canvas nodes ---
    /// Returns the appropriate node array based on the selected editor.
    /// The CanvasViews in the UI should bind to this property.
    var activeCanvasNodes: [BaseNode] {
        get {
            switch selectedEditor {
            case .schematic:
                return schematicCanvasNodes
            case .layout:
                return layoutCanvasNodes
            }
        }
        set {
            switch selectedEditor {
            case .schematic:
                schematicCanvasNodes = newValue
            case .layout:
                layoutCanvasNodes = newValue
            }
        }
    }
    // ---
    
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
        rebuildActiveCanvasNodes()
    }
    
    func addProperty(_ newProperty: Property.Instance, to component: ComponentInstance) {
        component.add(newProperty)
        rebuildActiveCanvasNodes()
    }
    
    func removeProperty(_ propertyToRemove: Property.Resolved, from component: ComponentInstance) {
        component.remove(propertyToRemove)
        rebuildActiveCanvasNodes()
    }

    // MARK: - Text Management (Unchanged)
    
    func toggleDynamicTextVisibility(for component: ComponentInstance, content: CircuitTextContent) {
        if let textToToggle = component.symbolInstance.resolvedItems.first(where: { $0.content.isSameType(as: content) }) {
            var editedText = textToToggle
            editedText.isVisible.toggle()
            updateText(for: component, with: editedText)
        } else {
            let existingTextPositions = component.symbolInstance.resolvedItems.map(\.relativePosition)
            let lowestY = existingTextPositions.map(\.y).min() ?? -20
            let newPosition = CGPoint(x: 0, y: lowestY - 10)
            
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
        
        let defaultOptions = component.definition?.symbol?.textDefinitions
            .first(where: { $0.content.isSameType(as: .componentProperty(definitionID: propertyDef.id, options: .default)) })?
            .content.displayOptions ?? .default
        
        let contentToToggle = CircuitTextContent.componentProperty(definitionID: propertyDef.id, options: defaultOptions)
        toggleDynamicTextVisibility(for: component, content: contentToToggle)
    }
    
    func updateText(for component: ComponentInstance, with editedText: CircuitText.Resolved) {
        component.apply(editedText)
        rebuildActiveCanvasNodes()
    }

    func addText(_ newText: CircuitText.Instance, to component: ComponentInstance) {
        component.add(newText)
        rebuildActiveCanvasNodes()
    }

    func removeText(_ textToRemove: CircuitText.Resolved, from component: ComponentInstance) {
        component.remove(textToRemove)
        rebuildActiveCanvasNodes()
    }

    // MARK: - Other Component Actions
    
    func updateReferenceDesignator(for component: ComponentInstance, newIndex: Int) {
        component.referenceDesignatorIndex = newIndex
        rebuildActiveCanvasNodes()
    }
    
    // MARK: - Canvas and Graph Management (Unchanged)
    
    private func makeGraph(from design: CircuitDesign) -> WireGraph {
        let newGraph = WireGraph()
        newGraph.build(from: design.wires)
        
        for inst in design.componentInstances {
            guard let symbolDef = inst.definition?.symbol else { continue }
            newGraph.syncPins(for: inst.symbolInstance, of: symbolDef, ownerID: inst.id)
        }
        return newGraph
    }
    
    private func generateRenderableTexts(for inst: ComponentInstance) -> [RenderableText] {
        return inst.symbolInstance.resolvedItems.map { resolvedModel in
            let displayString = self.generateString(for: resolvedModel, component: inst)
            return RenderableText(model: resolvedModel, text: displayString)
        }
    }
    
    // --- REFACTORED: Node rebuilding logic ---
    
    /// Rebuilds the canvas nodes for the currently active editor.
    func rebuildActiveCanvasNodes() {
        switch selectedEditor {
        case .schematic:
            rebuildSchematicNodes()
        case .layout:
            rebuildLayoutNodes()
        }
    }
    
    private func rebuildSchematicNodes() {
        guard let design = selectedDesign else {
            self.schematicCanvasNodes = []
            self.schematicGraph = WireGraph()
            return
        }
        
        let newGraph = self.makeGraph(from: design)
        self.schematicGraph = newGraph
        
        let symbolNodes: [SymbolNode] = design.componentInstances.compactMap { inst -> SymbolNode? in
            guard inst.symbolInstance.definition != nil else { return nil }
            let renderableTexts = self.generateRenderableTexts(for: inst)
            return SymbolNode(id: inst.id, instance: inst.symbolInstance, renderableTexts: renderableTexts, graph: self.schematicGraph)
        }
        let graphNode = SchematicGraphNode(graph: self.schematicGraph)
        graphNode.syncChildNodesFromModel()
        
        self.schematicCanvasNodes = symbolNodes + [graphNode]
    }
    
    private func rebuildLayoutNodes() {
        guard let design = selectedDesign else {
            self.layoutCanvasNodes = []
            return
        }
        
        // --- THIS IS THE KEY ---
        // We generate the canvas layers *once* here.
        let currentCanvasLayers = self.activeCanvasLayers
        
        let footprintNodes: [FootprintNode] = design.componentInstances.compactMap { inst in
            guard let footprintInst = inst.footprintInstance,
                  case .placed = footprintInst.placement,
                  footprintInst.definition != nil else {
                return nil
            }
            // Then we pass the generated layers to the node so it can resolve its children.
            return FootprintNode(id: inst.id, instance: footprintInst, canvasLayers: currentCanvasLayers)
        }
        
        self.layoutCanvasNodes = footprintNodes
    }

    func assignFootprint(to component: ComponentInstance, footprint: FootprintDefinition?) {
        if let footprint = footprint {
            // A newly assigned footprint is always .unplaced by default.
            let newFootprintInstance = FootprintInstance(
                definitionUUID: footprint.uuid,
                definition: footprint,
                placement: .unplaced
            )
            component.footprintInstance = newFootprintInstance
        } else {
            component.footprintInstance = nil
        }
    }

    func upsertSymbolNode(for inst: ComponentInstance) {
        guard inst.symbolInstance.definition != nil else { return }
        
        let renderableTexts = self.generateRenderableTexts(for: inst)
        
        guard let node = SymbolNode(id: inst.id, instance: inst.symbolInstance, renderableTexts: renderableTexts, graph: self.schematicGraph) else { return }
        
        if let idx = schematicCanvasNodes.firstIndex(where: { $0.id == inst.id }) {
            schematicCanvasNodes[idx] = node
        } else if let graphIndex = schematicCanvasNodes.firstIndex(where: { $0 is SchematicGraphNode }) {
            schematicCanvasNodes.insert(node, at: graphIndex)
        } else {
            let graphNode = SchematicGraphNode(graph: self.schematicGraph)
            graphNode.syncChildNodesFromModel()
            schematicCanvasNodes = [node, graphNode]
        }
    }
    
    /// Finds an unplaced component instance, changes its state to 'placed',
    /// sets its position, and rebuilds the layout canvas.
    /// - Parameters:
    ///   - instanceID: The UUID of the `ComponentInstance` to place.
    ///   - location: The canvas coordinates where the component was dropped.
    ///   - side: The board side to place the component on.
    func placeComponent(instanceID: UUID, at location: CGPoint, on side: BoardSide) {
        // 1. Find the specific component instance in the project.
        guard let component = componentInstances.first(where: { $0.id == instanceID }) else {
            print("Error: Could not find component instance with ID \(instanceID) to place.")
            return
        }
        
        // 2. Safely update its footprint instance.
        if let footprint = component.footprintInstance {
            // Change the state from .unplaced to .placed with the specified side.
            footprint.placement = .placed(side: side)
            // Set its initial position on the canvas.
            footprint.position = location
        }
        
        // 3. Rebuild the layout nodes so the new FootprintNode appears on the canvas.
        rebuildLayoutNodes()
    }
    
    /// Generates the array of `CanvasLayer` models for the currently active editor.
    /// This transforms the domain-specific `LayerType` into the generic `CanvasLayer` the renderer needs.
    var activeCanvasLayers: [CanvasLayer] {
        switch selectedEditor {
        case .schematic:
            return []
            
        case .layout:
            guard let design = selectedDesign else { return [] }
            
            return design.layers.map { layerType in
                CanvasLayer(
                    // --- THE FIX ---
                    // Directly use the stable UUID from the LayerType. No conversion needed.
                    id: layerType.id,
                    name: layerType.name,
                    isVisible: true,
                    color: NSColor(layerType.defaultColor).cgColor,
                    zIndex: layerType.kind.zIndex,
                    kind: layerType
                )
            }
        }
    }
    
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

extension CircuitTextContent {
    var displayOptions: TextDisplayOptions? {
        if case .componentProperty(_, let options) = self {
            return options
        }
        return nil
    }
}
