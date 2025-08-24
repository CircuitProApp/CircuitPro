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
    
    @MainActor
    func togglePropertyVisibility(for component: DesignComponent, property: Property.Resolved, using packManager: SwiftDataPackManager) {
        
        // We can only link text to properties with a stable definition ID.
        guard case .definition(let propertyDefID) = property.source else { return }

        guard let symbol = component.definition.symbol else { return }
        
        // --- THE NEW UNIFIED LOGIC ---

        // A. CHECK "HARD-BUILT" TEXTS: Does a text definition in the symbol already exist for this property?
        if let textDefinition = symbol.textDefinitions.first(where: {
            if case .dynamic(.property(let defID)) = $0.contentSource { return defID == propertyDefID }
            return false
        }) {
            // YES. This is a "hard-built" text. We toggle its visibility using an override.
            
            // Find or create the override for this text definition.
            if let overrideIndex = component.instance.symbolInstance.textOverrides.firstIndex(where: { $0.definitionID == textDefinition.id }) {
                // An override exists. Toggle its isVisible property.
                let currentVisibility = component.instance.symbolInstance.textOverrides[overrideIndex].isVisible ?? true
                component.instance.symbolInstance.textOverrides[overrideIndex].isVisible = !currentVisibility
            } else {
                // No override exists. Create one whose only purpose is to HIDE the text.
                let newOverride = CircuitText.Override(
                    definitionID: textDefinition.id,
                    isVisible: false // Default state is visible, so first toggle is always to hide.
                )
                component.instance.symbolInstance.textOverrides.append(newOverride)
            }
            
        // B. CHECK "AD-HOC" TEXTS: If no definition exists, check if an ad-hoc instance exists.
        } else if let instanceIndex = component.instance.symbolInstance.textInstances.firstIndex(where: {
            if case .dynamic(.property(let defID)) = $0.contentSource { return defID == propertyDefID }
            return false
        }) {
            // YES. An ad-hoc text is already visible. Toggling it means REMOVING it.
            component.instance.symbolInstance.textInstances.remove(at: instanceIndex)
            
        // C. CREATE "AD-HOC" TEXT: If neither exists, the property is not visible. Toggling it means CREATING an instance.
        } else {
            // Create a new ad-hoc text instance to show this property on the canvas.
            // (Layout logic is the same as before)
            let propertyTextPositions = component.instance.symbolInstance.textInstances
                .filter { if case .dynamic(.property) = $0.contentSource { return true }; return false }
                .map { $0.relativePosition }
            let lowestY = propertyTextPositions.map(\.y).min() ?? -20
            let newPosition = CGPoint(x: 0, y: lowestY - 12)

            let newTextInstance = CircuitText.Instance(
                id: UUID(),
                contentSource: .dynamic(.property(definitionID: propertyDefID)),
                text: "", // Will be generated by the now-fixed TextResolver
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
        
        // Finally, explicitly rebuild the canvas to reflect the changes.
        rebuildCanvasNodes(with: packManager)
    }
    
    @MainActor
    func updateReferenceDesignator(for component: DesignComponent, newIndex: Int, using packManager: SwiftDataPackManager) {
        // 1. Find the component instance in the project's array.
        guard let instanceIndex = self.componentInstances.firstIndex(where: { $0.id == component.id }) else {
            print("Error: Could not find component instance to update.")
            return
        }
        
        // 2. Update the model's value.
        self.componentInstances[instanceIndex].referenceDesignatorIndex = newIndex
        
        // 3. Rebuild the canvas nodes to reflect the change visually.
        // This is crucial for updating the text on the symbol.
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
