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

    // THIS IS THE KEY CHANGE: from a property to a method.
    @MainActor func designComponents(using packManager: SwiftDataPackManager) -> [DesignComponent] {
        let uuids = Set(componentInstances.map(\.componentUUID))
        guard !uuids.isEmpty else { return [] }

        // Use a temporary context from the main container to fetch definitions
        // from the user's library AND all installed packs.
        let fullLibraryContext = ModelContext(packManager.mainContainer)
        
        let request = FetchDescriptor<Component>(predicate: #Predicate { uuids.contains($0.uuid) })
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
    
    @MainActor
    func updateProperty(for component: DesignComponent, with editedProperty: Property.Resolved, using packManager: SwiftDataPackManager) {
        // We can only update properties that originate from a library definition,
        // as they are the only ones with overrides.
        guard case .definition(let definitionID) = editedProperty.source else {
            // You could handle updates to instance-specific properties differently here if needed.
            print("This property is an instance-specific property and cannot be updated this way.")
            return
        }

        // Find the original state of the property before the edit. This is crucial
        // for comparing what actually changed.
        guard let originalProperty = component.displayedProperties.first(where: { $0.id == editedProperty.id }) else {
            // This should not happen if the UI is consistent.
            print("Could not find the original property to compare against.")
            return
        }

        // 1. Check if the main value changed and update the model if it did.
        if originalProperty.value != editedProperty.value {
            component.instance.update(definitionID: definitionID, value: editedProperty.value)
        }

        // 2. Check if the unit's prefix changed and update the model if it did.
        if originalProperty.unit.prefix != editedProperty.unit.prefix {
            component.instance.update(definitionID: definitionID, prefix: editedProperty.unit.prefix)
        }
        
        // 3. Rebuild the canvas nodes to reflect the change.
        // This ensures things like resolved text fields (e.g., "{Value}") are updated visually.
        rebuildCanvasNodes(with: packManager)
    }
    
    // This method now accepts the packManager to do its work.
    @MainActor func rebuildCanvasNodes(with packManager: SwiftDataPackManager) {
        // 0. Load persisted wire data.
        if let wires = selectedDesign?.wires {
            schematicGraph.build(from: wires)
        }

        // Get the design components using the provided manager.
        let currentDesignComponents = self.designComponents(using: packManager)

        // 1. Sync pin vertices.
        for designComp in currentDesignComponents {
            guard let symbolDefinition = designComp.definition.symbol else { continue }
            schematicGraph.syncPins(
                for: designComp.instance.symbolInstance,
                of: symbolDefinition,
                ownerID: designComp.id
            )
        }
        
        // 1a. Normalize the graph.
        schematicGraph.normalize(around: Set(schematicGraph.vertices.keys))

        // 2. Build the Symbol nodes.
        let symbolNodes: [SymbolNode] = currentDesignComponents.compactMap { designComp in
            guard let symbolDefinition = designComp.definition.symbol else { return nil }
            
            let resolvedProperties = designComp.displayedProperties
            
            let resolvedTexts = TextResolver.resolve(
                definitions: symbolDefinition.textDefinitions,
                overrides: designComp.instance.symbolInstance.textOverrides,
                instances: designComp.instance.symbolInstance.textInstances,
                componentName: designComp.definition.name,
                reference: designComp.referenceDesignator,
                properties: resolvedProperties
            )
            
            return SymbolNode(
                id: designComp.id,
                instance: designComp.instance.symbolInstance,
                symbol: symbolDefinition,
                resolvedTexts: resolvedTexts,
                graph: schematicGraph
            )
        }

        // 3. Build the Graph node.
        let graphNode = SchematicGraphNode(graph: schematicGraph)
        graphNode.syncChildNodesFromModel()

        // 4. Update the single source of truth for the canvas.
        let newNodeIDs = Set(symbolNodes.map(\.id) + [graphNode.id])
        let currentNodeIDs = Set(self.canvasNodes.map(\.id))
        
        if newNodeIDs != currentNodeIDs {
            self.canvasNodes = symbolNodes + [graphNode]
        }
    }
}
