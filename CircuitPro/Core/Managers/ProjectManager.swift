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
    
    // --- NEW & REFACTORED VISIBILITY METHODS ---

    @MainActor
    func toggleDynamicTextVisibility(for component: DesignComponent, source: DynamicComponentProperty, using packManager: SwiftDataPackManager) {
        // Ensure the component's symbol definition exists.
        guard let symbol = component.definition.symbol else { return }

        // Case 1: The text is defined in the symbol definition. We toggle its visibility via an override.
        if let textDefinition = symbol.textDefinitions.first(where: {
            if case .dynamic(let dynamicSource) = $0.contentSource { return dynamicSource == source }
            return false
        }) {
            if let overrideIndex = component.instance.symbolInstance.textOverrides.firstIndex(where: { $0.definitionID == textDefinition.id }) {
                // If an override exists, toggle its isVisible flag.
                let currentVisibility = component.instance.symbolInstance.textOverrides[overrideIndex].isVisible ?? true
                component.instance.symbolInstance.textOverrides[overrideIndex].isVisible = !currentVisibility
            } else {
                // If no override exists, create one to hide the text (since it's visible by default).
                let newOverride = CircuitText.Override(definitionID: textDefinition.id, isVisible: false)
                component.instance.symbolInstance.textOverrides.append(newOverride)
            }
        // Case 2: The text exists as a user-added instance (not from the original definition). We remove it to hide it.
        } else if let instanceIndex = component.instance.symbolInstance.textInstances.firstIndex(where: {
            if case .dynamic(let dynamicSource) = $0.contentSource { return dynamicSource == source }
            return false
        }) {
            component.instance.symbolInstance.textInstances.remove(at: instanceIndex)
        // Case 3: The text is not displayed at all. We create a new instance to show it.
        } else {
            // Find a reasonable default position for the new text.
            let existingTextPositions = component.instance.symbolInstance.textInstances.map(\.relativePosition)
            let lowestY = existingTextPositions.map(\.y).min() ?? -20
            let newPosition = CGPoint(x: 0, y: lowestY - 10)
            
            // Create and add the new text instance.
            let newTextInstance = CircuitText.Instance(
                id: UUID(),
                contentSource: .dynamic(source),
                text: "", // The resolver will provide the actual string content.
                relativePosition: newPosition,
                definitionPosition: newPosition,
                font: .init(font: .systemFont(ofSize: 12)),
                color: .init(color: .black),
                anchor: .leading,
                alignment: .left,
                cardinalRotation: .east,
                isVisible: true
            )
            component.instance.symbolInstance.textInstances.append(newTextInstance)
        }
        
        // Trigger a rebuild to reflect the changes on the canvas.
        rebuildCanvasNodes(with: packManager)
    }

    @MainActor
    func togglePropertyVisibility(for component: DesignComponent, property: Property.Resolved, using packManager: SwiftDataPackManager) {
        // This method now serves as a convenience wrapper around the more generic toggle function.
        guard case .definition(let propertyDefID) = property.source else {
            print("Error: Visibility can only be toggled for definition-based properties.")
            return
        }
        let source = DynamicComponentProperty.property(definitionID: propertyDefID)
        toggleDynamicTextVisibility(for: component, source: source, using: packManager)
    }

    // --- The following methods are unchanged ---

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
    func updateReferenceDesignator(for component: DesignComponent, newIndex: Int, using packManager: SwiftDataPackManager) {
        guard let instanceIndex = self.componentInstances.firstIndex(where: { $0.id == component.id }) else {
            print("Error: Could not find component instance to update.")
            return
        }
        self.componentInstances[instanceIndex].referenceDesignatorIndex = newIndex
        rebuildCanvasNodes(with: packManager)
    }

    /// Creates a new, fully initialized `WireGraph` from the current design state.
    @MainActor
    private func makeGraph(from design: CircuitDesign, using packManager: SwiftDataPackManager) -> WireGraph {
        let newGraph = WireGraph()
        newGraph.build(from: design.wires)
        let designComponents = self.designComponents(using: packManager)
        for comp in designComponents {
            guard let symbolDef = comp.definition.symbol else { continue }
            newGraph.syncPins(
                for: comp.instance.symbolInstance,
                of: symbolDef,
                ownerID: comp.id
            )
        }
        return newGraph
    }

    @MainActor
    func rebuildCanvasNodes(with packManager: SwiftDataPackManager) {
        guard let design = selectedDesign else {
            self.canvasNodes = []
            self.schematicGraph = WireGraph() // Reset to empty
            return
        }

        let newGraph = self.makeGraph(from: design, using: packManager)
        self.schematicGraph = newGraph

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

        let graphNode = SchematicGraphNode(graph: self.schematicGraph)
        graphNode.syncChildNodesFromModel()

        self.canvasNodes = symbolNodes + [graphNode]
    }
}
