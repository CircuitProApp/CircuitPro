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

    var componentInstances: [ComponentInstance] {
        get { selectedDesign?.componentInstances ?? [] }
        set { selectedDesign?.componentInstances = newValue }
    }

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

    func persistSchematicGraph() {
        guard selectedDesign != nil else { return }
        selectedDesign?.wires = schematicGraph.toWires()
    }
    

    @MainActor
    func toggleDynamicTextVisibility(for component: DesignComponent, source: TextSource, using packManager: SwiftDataPackManager) {
        guard let symbol = component.definition.symbol else { return }

        // Case 1: The text is defined in the symbol definition. We toggle its visibility via an override.
        if let textDefinition = symbol.textDefinitions.first(where: { $0.contentSource == source }) {
            if let overrideIndex = component.instance.symbolInstance.textOverrides.firstIndex(where: { $0.definitionID == textDefinition.id }) {
                let currentVisibility = component.instance.symbolInstance.textOverrides[overrideIndex].isVisible ?? true
                component.instance.symbolInstance.textOverrides[overrideIndex].isVisible = !currentVisibility
            } else {
                let newOverride = CircuitText.Override(definitionID: textDefinition.id, isVisible: false)
                component.instance.symbolInstance.textOverrides.append(newOverride)
            }
            
        // Case 2: The text exists as a user-added instance. We toggle its visibility.
        } else if let instanceIndex = component.instance.symbolInstance.textInstances.firstIndex(where: { $0.contentSource == source }) {
            let currentVisibility = component.instance.symbolInstance.textInstances[instanceIndex].isVisible
            component.instance.symbolInstance.textInstances[instanceIndex].isVisible = !currentVisibility
            
        // Case 3: The text is not displayed at all. We create a new instance to show it.
        } else {
            let existingTextPositions = component.instance.symbolInstance.textInstances.map(\.relativePosition)
            let lowestY = existingTextPositions.map(\.y).min() ?? -20
            let newPosition = CGPoint(x: 0, y: lowestY - 10)
            
            let newTextInstance = CircuitText.Instance(
                id: UUID(),
                contentSource: source,
                relativePosition: newPosition,
                anchorPosition: newPosition,
                font: .init(font: .systemFont(ofSize: 12)),
                color: .init(color: .black),
                anchor: .leading,
                alignment: .left,
                cardinalRotation: .east,
                isVisible: true
            )
            component.instance.symbolInstance.textInstances.append(newTextInstance)
        }
        
        rebuildCanvasNodes(with: packManager)
    }

    @MainActor
    func togglePropertyVisibility(for component: DesignComponent, property: Property.Resolved, using packManager: SwiftDataPackManager) {
        guard case .definition(let propertyDefID) = property.source else {
            print("Error: Visibility can only be toggled for definition-based properties.")
            return
        }
        let source = TextSource.componentProperty(definitionID: propertyDefID)
        toggleDynamicTextVisibility(for: component, source: source, using: packManager)
    }
    
    @MainActor
    func updateProperty(for component: DesignComponent, with editedProperty: Property.Resolved, using packManager: SwiftDataPackManager) {
        guard case .definition(let definitionID) = editedProperty.source else { return }
        guard let originalProperty = component.displayedProperties.first(where: { $0.id == editedProperty.id }) else { return }
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
        guard let instanceIndex = self.componentInstances.firstIndex(where: { $0.id == component.id }) else { return }
        self.componentInstances[instanceIndex].referenceDesignatorIndex = newIndex
        rebuildCanvasNodes(with: packManager)
    }

    @MainActor
    private func makeGraph(from design: CircuitDesign, using packManager: SwiftDataPackManager) -> WireGraph {
        let newGraph = WireGraph()
        newGraph.build(from: design.wires)
        let designComponents = self.designComponents(using: packManager)
        for comp in designComponents {
            guard let symbolDef = comp.definition.symbol else { continue }
            newGraph.syncPins(for: comp.instance.symbolInstance, of: symbolDef, ownerID: comp.id)
        }
        return newGraph
    }

    @MainActor
    func rebuildCanvasNodes(with packManager: SwiftDataPackManager) {
        guard let design = selectedDesign else {
            self.canvasNodes = []
            self.schematicGraph = WireGraph()
            return
        }

        let newGraph = self.makeGraph(from: design, using: packManager)
        self.schematicGraph = newGraph

        let currentDesignComponents = self.designComponents(using: packManager)
        
        let symbolNodes: [SymbolNode] = currentDesignComponents.compactMap { designComp in
            guard let symbolDefinition = designComp.definition.symbol else { return nil }
            
            // --- THE PAYOFF ---
            // The call to `resolve` is now incredibly clean. We just pass the `designComp` itself.
            let resolvedTexts = TextResolver.resolve(
                definitions: symbolDefinition.textDefinitions,
                overrides: designComp.instance.symbolInstance.textOverrides,
                instances: designComp.instance.symbolInstance.textInstances,
                for: designComp // Pass the whole smart component.
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
