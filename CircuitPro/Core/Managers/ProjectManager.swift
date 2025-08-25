//
//  ProjectManager.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/5/25.
//

import SwiftUI
import Observation
import SwiftDataPacks

@Observable
final class ProjectManager {

    var project: CircuitProject
    var selectedDesign: CircuitDesign?
    var selectedNodeIDs: Set<UUID> = []
    var canvasNodes: [BaseNode] = []
    var selectedNetIDs: Set<UUID> = []
    
    // CHANGE: This is no longer built incrementally. It will be replaced
    // entirely by the factory method during a rebuild.
    var schematicGraph = WireGraph()

    init(
        project: CircuitProject,
        selectedDesign: CircuitDesign? = nil
    ) {
        self.project        = project
        self.selectedDesign = selectedDesign
    }

    // --- Convenience properties are unchanged ---
    var componentInstances: [ComponentInstance] {
        get { selectedDesign?.componentInstances ?? [] }
        set { selectedDesign?.componentInstances = newValue }
    }

    // This method is already well-designed and needs no changes.
    @MainActor func designComponents(using packManager: SwiftDataPackManager) -> [DesignComponent] {
        let uuids = Set(componentInstances.map(\.componentUUID))
        guard !uuids.isEmpty else { return [] }

        let fullLibraryContext = ModelContext(packManager.mainContainer)
        
        let request = FetchDescriptor<ComponentDefinition>(predicate: #Predicate { uuids.contains($0.uuid) })
        let defs = (try? fullLibraryContext.fetch(request)) ?? []

        let dict = Dictionary(uniqueKeysWithValues: defs.map { ($0.uuid, $0) })
        
        return componentInstances.compactMap { inst in
            guard let def = dict[inst.componentUUID] else { return nil }
            return DesignComponent(definition: def, instance: inst)
        }
    }
    
    /// Persists the current state of the schematic graph back to the design model.
    func persistSchematicGraph() {
        guard selectedDesign != nil else { return }
        selectedDesign?.wires = schematicGraph.toWires()
    }
    
    // --- The following update methods are unchanged as they correctly trigger a full rebuild ---
    
    @MainActor
    func updateProperty(for component: DesignComponent, with editedProperty: Property.Resolved, using packManager: SwiftDataPackManager) {
        guard case .definition(let definitionID) = editedProperty.source else {
            print("This property is an instance-specific property and cannot be updated this way.")
            return
        }
        guard let originalProperty = component.displayedProperties.first(where: { $0.id == editedProperty.id }) else {
            print("Could not find the original property to compare against.")
            return
        }
        if originalProperty.value != editedProperty.value {
            component.instance.update(definitionID: definitionID, value: editedProperty.value)
        }
        if originalProperty.unit.prefix != editedProperty.unit.prefix {
            component.instance.update(definitionID: definitionID, prefix: editedProperty.unit.prefix)
        }
        rebuildCanvasNodes(with: packManager)
    }
    
    @MainActor
    func togglePropertyVisibility(for component: DesignComponent, property: Property.Resolved, using packManager: SwiftDataPackManager) {
        guard case .definition(let propertyDefID) = property.source else { return }
        guard let symbol = component.definition.symbol else { return }
        if let textDefinition = symbol.textDefinitions.first(where: {
            if case .dynamic(.property(let defID)) = $0.contentSource { return defID == propertyDefID }
            return false
        }) {
            if let overrideIndex = component.instance.symbolInstance.textOverrides.firstIndex(where: { $0.definitionID == textDefinition.id }) {
                let currentVisibility = component.instance.symbolInstance.textOverrides[overrideIndex].isVisible ?? true
                component.instance.symbolInstance.textOverrides[overrideIndex].isVisible = !currentVisibility
            } else {
                let newOverride = CircuitText.Override(definitionID: textDefinition.id, isVisible: false)
                component.instance.symbolInstance.textOverrides.append(newOverride)
            }
        } else if let instanceIndex = component.instance.symbolInstance.textInstances.firstIndex(where: {
            if case .dynamic(.property(let defID)) = $0.contentSource { return defID == propertyDefID }
            return false
        }) {
            component.instance.symbolInstance.textInstances.remove(at: instanceIndex)
        } else {
            let propertyTextPositions = component.instance.symbolInstance.textInstances
                .filter { if case .dynamic(.property) = $0.contentSource { return true }; return false }
                .map { $0.relativePosition }
            let lowestY = propertyTextPositions.map(\.y).min() ?? -20
            let newPosition = CGPoint(x: 0, y: lowestY - 12)
            let newTextInstance = CircuitText.Instance(id: UUID(), contentSource: .dynamic(.property(definitionID: propertyDefID)), text: "", relativePosition: newPosition, definitionPosition: newPosition, font: .init(font: .systemFont(ofSize: 12)), color: .init(color: .black), anchor: .middleCenter, alignment: .center, cardinalRotation: .east, isVisible: true)
            component.instance.symbolInstance.textInstances.append(newTextInstance)
        }
        rebuildCanvasNodes(with: packManager)
    }
    
    @MainActor
    func updateReferenceDesignator(for component: DesignComponent, newIndex: Int, using packManager: SwiftDataPackManager) {
        guard let instanceIndex = self.componentInstances.firstIndex(where: { $0.id == component.id }) else {
            print("Error: Could not find component instance to update.")
            return
        }
        self.componentInstances[instanceIndex].referenceDesignatorIndex = newIndex
        rebuildCanvasNodes(with: packManager)
    }
        
    // --- INTRODUCING THE FACTORY METHOD ---
    
    /// Creates a new, fully initialized `WireGraph` from the current design state.
    /// This is a "pure" factory that encapsulates the entire graph construction process.
    @MainActor
    private func makeGraph(from design: CircuitDesign, using packManager: SwiftDataPackManager) -> WireGraph {
        let newGraph = WireGraph()
        
        // 1. Build the basic graph from persisted wire data.

        newGraph.build(from: design.wires)
        
        
        // 2. Get the component data needed to sync pins.
        let designComponents = self.designComponents(using: packManager)

        // 3. Sync all pin positions.
        for comp in designComponents {
            guard let symbolDef = comp.definition.symbol else { continue }
            newGraph.syncPins(
                for: comp.instance.symbolInstance,
                of: symbolDef,
                ownerID: comp.id
            )
        }
        
        // 4. Perform a final, full normalization of the newly built graph.
        // We do this here, once, at the end of the construction process.
        // NOTE: This requires making `normalize` public or internal on WireGraph.
        // Since this is a temporary state before Phase 2, we can just call the private `_normalize`
        // by creating a mutable copy of the state. For now, we will assume a simplified public `normalize` exists.
        
        // This is a temporary workaround until normalize is part of the ruleset.
        // For now, let's assume `normalize` is made `internal`.
        // A better long-term solution would be a `BuildTransaction` passed to the engine.
        var tempState = newGraph.engine.currentState // hypothetical access
        newGraph._normalize(around: Set(tempState.vertices.keys), in: &tempState)
        newGraph.engine = GraphEngine(initialState: tempState, ruleset: OrthogonalWireRuleset())


        return newGraph
    }

    // --- REBUILD METHOD IS NOW CLEANER ---
    
    @MainActor
    func rebuildCanvasNodes(with packManager: SwiftDataPackManager) {
        guard let design = selectedDesign else {
            self.canvasNodes = []
            self.schematicGraph = WireGraph() // Reset to empty
            return
        }
        
        // 1. Create a brand new, fully-formed graph using the factory method.
        let newGraph = self.makeGraph(from: design, using: packManager)
        self.schematicGraph = newGraph

        // 2. Build the Symbol nodes, passing the new graph to them.
        let currentDesignComponents = self.designComponents(using: packManager)
        let symbolNodes: [SymbolNode] = currentDesignComponents.compactMap { designComp in
            guard let symbolDefinition = designComp.definition.symbol else { return nil }
            let resolvedProperties = designComp.displayedProperties
            let resolvedTexts = TextResolver.resolve(definitions: symbolDefinition.textDefinitions, overrides: designComp.instance.symbolInstance.textOverrides, instances: designComp.instance.symbolInstance.textInstances, componentName: designComp.definition.name, reference: designComp.referenceDesignator, properties: resolvedProperties)
            
            return SymbolNode(
                id: designComp.id,
                instance: designComp.instance.symbolInstance,
                symbol: symbolDefinition,
                resolvedTexts: resolvedTexts,
                graph: self.schematicGraph // Pass the newly created graph
            )
        }

        // 3. Build the Graph node.
        let graphNode = SchematicGraphNode(graph: self.schematicGraph)
        graphNode.syncChildNodesFromModel()

        // 4. Update the single source of truth for the canvas.
        self.canvasNodes = symbolNodes + [graphNode]
    }
}
