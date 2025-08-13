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

    // 1. Convenience
    var componentInstances: [ComponentInstance] {
        get { selectedDesign?.componentInstances ?? [] }
        set { selectedDesign?.componentInstances = newValue }
    }

    // 2. Centralised lookup
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
        // 1. Ensure the graph model is synchronized first
        for designComp in designComponents {
            guard let symbolDefinition = designComp.definition.symbol else { continue }
            schematicGraph.syncPins(
                for: designComp.instance.symbolInstance,
                of: symbolDefinition,
                ownerID: designComp.id
            )
        }

        // 2. Build the Symbol nodes using compactMap
        // This allows the closure to return `nil` for components without a symbol.
        let symbolNodes: [SymbolNode] = designComponents.compactMap { designComp in
            guard let symbolDefinition = designComp.definition.symbol else { return nil }
            
            // Get the resolved properties directly from the DesignComponent.
            let resolvedProperties = designComp.displayedProperties
            
            // Pass the new [Property.Resolved] type to the TextResolver.
            // This assumes TextResolver has been updated to accept [Property.Resolved].
            let resolvedTexts = TextResolver.resolve(
                from: symbolDefinition,
                and: designComp.instance.symbolInstance,
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

        // 3. Build the Graph node
        let graphNode = SchematicGraphNode(graph: schematicGraph)
        graphNode.syncChildNodesFromModel()

        // 4. Update the single source of truth for the canvas
        let newNodeIDs = Set(symbolNodes.map(\.id) + [graphNode.id])
        let currentNodeIDs = Set(self.canvasNodes.map(\.id))
        
        if newNodeIDs != currentNodeIDs {
            self.canvasNodes = symbolNodes + [graphNode]
        }
    }
}
