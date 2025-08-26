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

    // The graph is now driven by the engine + ruleset via transactions.
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
            let newTextInstance = CircuitText.Instance(
                id: UUID(),
                contentSource: .dynamic(.property(definitionID: propertyDefID)),
                text: "",
                relativePosition: newPosition,
                definitionPosition: newPosition,
                font: .init(font: .systemFont(ofSize: 12)),
                color: .init(color: .black),
                anchor: .middleCenter,
                alignment: .center,
                cardinalRotation: .east,
                isVisible: true
            )
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
    /// With the new architecture, we let the ruleset normalize incrementally as we place pins.
    @MainActor
    private func makeGraph(from design: CircuitDesign, using packManager: SwiftDataPackManager) -> WireGraph {
        let newGraph = WireGraph()

        // 1) Build from persisted wires (bulk replace of state)
        newGraph.build(from: design.wires)

        // 2) Resolve components used in the design
        let designComponents = self.designComponents(using: packManager)

        // 3) Sync all pin positions (each call uses transactions; ruleset normalizes around affected pins)
        for comp in designComponents {
            guard let symbolDef = comp.definition.symbol else { continue }
            newGraph.syncPins(
                for: comp.instance.symbolInstance,
                of: symbolDef,
                ownerID: comp.id
            )
        }

        // Optional: if you want a final global normalization pass, add a public
        // `normalizeAll()` on WireGraph that executes a no-op transaction with
        // epicenter = all vertices. For now, we rely on per-pin normalization.

        return newGraph
    }

    // --- REBUILD METHOD ---

    @MainActor
    func rebuildCanvasNodes(with packManager: SwiftDataPackManager) {
        guard let design = selectedDesign else {
            self.canvasNodes = []
            self.schematicGraph = WireGraph() // Reset to empty
            return
        }

        // 1) Build a brand new graph using the factory
        let newGraph = self.makeGraph(from: design, using: packManager)
        self.schematicGraph = newGraph

        // 2) Build symbol nodes with the new graph
        let currentDesignComponents = self.designComponents(using: packManager)
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
                graph: self.schematicGraph
            )
        }

        // 3) Graph node
        let graphNode = SchematicGraphNode(graph: self.schematicGraph)
        graphNode.syncChildNodesFromModel()

        // 4) Update canvas
        self.canvasNodes = symbolNodes + [graphNode]
    }
}
