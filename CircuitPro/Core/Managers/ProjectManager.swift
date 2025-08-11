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
        // 2.1 gather the UUIDs the design references
        let uuids = Set(componentInstances.map(\.componentUUID))
        guard !uuids.isEmpty else { return [] }

        // 2.2 fetch all definitions in ONE round-trip
        let request = FetchDescriptor<Component>(predicate: #Predicate { uuids.contains($0.uuid) })
        let defs = (try? modelContext.fetch(request)) ?? []

        // 2.3 build a dictionary for fast lookup
        let dict = Dictionary(uniqueKeysWithValues: defs.map { ($0.uuid, $0) })

        // 2.4 zip every instance with its definition (skip dangling refs gracefully)
        return componentInstances.compactMap { inst in
            guard let def = dict[inst.componentUUID] else { return nil }
            return DesignComponent(definition: def, instance: inst)
        }
    }
    
    func rebuildCanvasNodes() {
        // This logic is moved from SchematicCanvasView.syncNodesFromProjectManager
        
        // 1. Ensure the graph model is synchronized first
        for designComp in designComponents {
            guard let symbolDefinition = designComp.definition.symbol else { continue }
            schematicGraph.syncPins(
                for: designComp.instance.symbolInstance,
                of: symbolDefinition,
                ownerID: designComp.id
            )
        }

        // 2. Build the Symbol nodes
        let symbolNodes: [SymbolNode] = designComponents.compactMap { designComp in
            guard let symbolDefinition = designComp.definition.symbol else { return nil }
            let resolvedProperties = PropertyResolver.resolve(from: designComp.definition, and: designComp.instance)
            let resolvedTexts = TextResolver.resolve(from: symbolDefinition, and: designComp.instance.symbolInstance, componentName: designComp.definition.name, reference: designComp.referenceDesignator, properties: resolvedProperties)
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
        // The check for changes is still a good optimization.
        let newNodeIDs = Set(symbolNodes.map(\.id) + [graphNode.id])
        let currentNodeIDs = Set(self.canvasNodes.map(\.id))
        
        if newNodeIDs != currentNodeIDs {
            self.canvasNodes = symbolNodes + [graphNode]
        }
    }
}
