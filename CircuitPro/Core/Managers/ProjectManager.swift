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
    var selectedDesign: CircuitDesign? {
        didSet { activeLayerId = nil }
    }
    var selectedNodeIDs: Set<UUID> = []
    
    var schematicCanvasNodes: [BaseNode] = []
    var layoutCanvasNodes: [BaseNode] = []
    
    var selectedNetIDs: Set<UUID> = []
    
    var selectedEditor: EditorType = .schematic
    
    var selectedTool: CanvasTool = CursorTool()
    
    var schematicGraph = WireGraph()
    var traceGraph = TraceGraph()
    
    var activeLayerId: UUID? = nil
    
    // --- MODIFIED: This is now a stored property to allow binding from the UI. ---
    var activeCanvasLayers: [CanvasLayer] = []
    
    init(
        project: CircuitProject,
        selectedDesign: CircuitDesign? = nil
    ) {
        self.project        = project
        self.selectedDesign = selectedDesign
    }
    
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
    
    var componentInstances: [ComponentInstance] {
        get { selectedDesign?.componentInstances ?? [] }
        set { selectedDesign?.componentInstances = newValue }
    }
    
    func persistSchematicGraph() {
        guard selectedDesign != nil else { return }
        selectedDesign?.wires = schematicGraph.toWires()
    }

    func persistTraceGraph() {
        print("Fake persisting TraceGraph...")
    }

    func handleNewNode(_ node: BaseNode) {
        if let traceRequest = node as? TraceRequestNode {
            traceGraph.addTrace(
                path: traceRequest.points,
                width: traceRequest.width,
                layerId: traceRequest.layerId
            )
            persistTraceGraph()
            rebuildLayoutNodes()
        }
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
    
    private func generateRenderableTexts(for inst: ComponentInstance) -> [RenderableText] {
        return inst.symbolInstance.resolvedItems.map { resolvedModel in
            let displayString = self.generateString(for: resolvedModel, component: inst)
            return RenderableText(model: resolvedModel, text: displayString)
        }
    }
    
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
            // --- ADDED: Ensure layers are cleared for the schematic view. ---
            self.activeCanvasLayers = []
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
        // --- ADDED: Ensure layers are cleared for the schematic view. ---
        self.activeCanvasLayers = []
    }
    
    private func rebuildLayoutNodes() {
        guard let design = selectedDesign else {
            self.layoutCanvasNodes = []
            self.activeCanvasLayers = []
            return
        }
        
        // --- THIS IS THE FIX ---

        // 1. Generate the canvas layers from the project's source of truth.
        let unsortedCanvasLayers = design.layers.map { layerType in
            CanvasLayer(
                id: layerType.id,
                name: layerType.name,
                isVisible: true,
                color: NSColor(layerType.defaultColor).cgColor,
                zIndex: layerType.kind.zIndex,
                kind: layerType // Keep the original LayerType for sorting
            )
        }

        // 2. Sort the layers to establish the correct global drawing order (bottom-to-top).
        let sortedCanvasLayers = unsortedCanvasLayers.sorted { (layerA, layerB) -> Bool in
            // Primary sort key: zIndex (e.g., copper is drawn before silkscreen).
            if layerA.zIndex != layerB.zIndex {
                return layerA.zIndex < layerB.zIndex
            }
            
            // Secondary sort key: Physical side (e.g., back copper is drawn before front copper).
            guard let typeA = layerA.kind as? LayerType, let sideA = typeA.side,
                  let typeB = layerB.kind as? LayerType, let sideB = typeB.side else {
                // Fallback for layers without a side (like board outline)
                return false
            }
            
            return sideA.drawingOrder < sideB.drawingOrder
        }
        
        // 3. Store the correctly sorted layers. This is now the source of truth for rendering.
        self.activeCanvasLayers = sortedCanvasLayers
        
        // The rest of the function remains the same, but now uses the correctly ordered layers.
        let footprintNodes: [FootprintNode] = design.componentInstances.compactMap { inst in
            guard let footprintInst = inst.footprintInstance,
                  case .placed = footprintInst.placement,
                  footprintInst.definition != nil else {
                return nil
            }
            // Pass the sorted layers to the footprint node
            return FootprintNode(id: inst.id, instance: footprintInst, canvasLayers: self.activeCanvasLayers)
        }
        
        let traceGraphNode = TraceGraphNode(graph: self.traceGraph)
        // Pass the sorted layers to the trace graph node
        traceGraphNode.syncChildNodesFromModel(canvasLayers: self.activeCanvasLayers)
        
        self.layoutCanvasNodes = footprintNodes + [traceGraphNode]
    }

    func assignFootprint(to component: ComponentInstance, footprint: FootprintDefinition?) {
        if let footprint = footprint {
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
    
    func placeComponent(instanceID: UUID, at location: CGPoint, on side: BoardSide) {
        guard let component = componentInstances.first(where: { $0.id == instanceID }) else {
            print("Error: Could not find component instance with ID \(instanceID) to place.")
            return
        }
        
        if let footprint = component.footprintInstance {
            footprint.placement = .placed(side: side)
            footprint.position = location
        }
        
        rebuildLayoutNodes()
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
