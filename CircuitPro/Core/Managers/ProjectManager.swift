//
//  CanvasManager 2.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/5/25.
//

import SwiftUI
import Observation
import SwiftData

@Observable
final class ProjectManager {

    let modelContext: ModelContext
    var project: CircuitProject
    var selectedDesign: CircuitDesign?
    var selectedComponentIDs: Set<UUID> = []
    var canvasNodes: [BaseNode] = []
    var selectedNetIDs: Set<UUID> = []
    var schematicGraph = WireGraph()

    init(
        project: CircuitProject,
        selectedDesign: CircuitDesign? = nil,
        modelContext: ModelContext
    ) {
        self.project        = project
        self.selectedDesign = selectedDesign
        self.modelContext   = modelContext
    }

    // --- Convenience properties are unchanged ---
    var componentInstances: [ComponentInstance] {
        get { selectedDesign?.componentInstances ?? [] }
        set { selectedDesign?.componentInstances = newValue }
    }

    var designComponents: [DesignComponent] {
        let uuids = Set(componentInstances.map(\.componentUUID))
        guard !uuids.isEmpty else { return [] }

        let request = FetchDescriptor<Component>(predicate: #Predicate { uuids.contains($0.uuid) })
        let defs = (try? modelContext.fetch(request)) ?? []

        let dict = Dictionary(uniqueKeysWithValues: defs.map { ($0.uuid, $0) })

        return componentInstances.compactMap { inst in
            guard let def = dict[inst.componentUUID] else { return nil }
            return DesignComponent(definition: def, instance: inst)
        }
    }
    
    func rebuildCanvasNodes() {
        // 1. Sync the wire graph model first. (Unchanged)
        for designComp in designComponents {
            guard let symbolDefinition = designComp.definition.symbol else { continue }
            schematicGraph.syncPins(
                for: designComp.instance.symbolInstance,
                of: symbolDefinition,
                ownerID: designComp.id
            )
        }

        // 2. Build the Symbol nodes.
        let symbolNodes: [SymbolNode] = designComponents.compactMap { designComp in
            guard let symbolDefinition = designComp.definition.symbol else { return nil }
            
            let resolvedProperties = designComp.displayedProperties
            
            // THE FIX: Call TextResolver with the new, correct signature.
            // We now pass the specific arrays of definitions, overrides, and instances.
            let resolvedTexts = TextResolver.resolve(
                definitions: symbolDefinition.textDefinitions,
                overrides: designComp.instance.symbolInstance.textOverrides,
                instances: designComp.instance.symbolInstance.textInstances,
                componentName: designComp.definition.name,
                reference: designComp.referenceDesignator,
                properties: resolvedProperties
            )
            
            // This SymbolNode initializer is now correct because `resolvedTexts`
            // is the correct `[CircuitText.Resolved]` type.
            return SymbolNode(
                id: designComp.id,
                instance: designComp.instance.symbolInstance,
                symbol: symbolDefinition,
                resolvedTexts: resolvedTexts,
                graph: schematicGraph
            )
        }

        // 3. Build the Graph node. (Unchanged)
        let graphNode = SchematicGraphNode(graph: schematicGraph)
        graphNode.syncChildNodesFromModel()

        // 4. Update the single source of truth for the canvas. (Unchanged)
        let newNodeIDs = Set(symbolNodes.map(\.id) + [graphNode.id])
        let currentNodeIDs = Set(self.canvasNodes.map(\.id))
        
        if newNodeIDs != currentNodeIDs {
            self.canvasNodes = symbolNodes + [graphNode]
        }
    }
}
