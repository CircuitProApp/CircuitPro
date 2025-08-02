import SwiftUI
import SwiftData

struct SchematicView: View {

    // Injected
    var document: CircuitProjectDocument
    var canvasManager = CanvasManager()

    @Environment(\.projectManager)
    private var projectManager

    // Canvas state
    @State private var canvasElements: [CanvasElement] = []
    @State private var selectedTool: AnyCanvasTool = .init(CursorTool())
    @State private var nets: [SchematicGraph.Net] = []

    var body: some View {
        @Bindable var bindableProjectManager = projectManager

        CanvasView(
            manager: canvasManager,
            schematicGraph: projectManager.schematicGraph,
            elements: $canvasElements,
            selectedIDs: $bindableProjectManager.selectedComponentIDs,
            selectedTool: $selectedTool,
            onComponentDropped: { component, point in
                addComponents([component], at: point)
            }
        )
        .overlay(alignment: .leading) {
            SchematicToolbarView(selectedSchematicTool: $selectedTool)
                .padding(16)
        }
        .onAppear {
            rebuildCanvasElements()
        }

        // Rebuild when the data model changes
        .onChange(of: projectManager.componentInstances) {
            rebuildCanvasElements()
        }
        // Analyze the graph when it changes
        .onChange(of: projectManager.schematicGraph.vertices) { _, _ in updateNets() }
        .onChange(of: projectManager.schematicGraph.edges) { _, _ in updateNets() }
        // Persist all UI changes back to the model
        .onChange(of: canvasElements) { _, newValue in
            syncCanvasToModel(newValue)
        }
        // When canvas selection changes, check if we need to deselect in the navigator
        .onChange(of: projectManager.selectedComponentIDs) { _, newSelection in
            let selectedEdges = newSelection.filter { projectManager.schematicGraph.edges[$0] != nil }
            if selectedEdges.isEmpty {
                projectManager.selectedNetIDs.removeAll()
            }
        }
    }

    private func updateNets() {
        nets = projectManager.schematicGraph.findNets()
    }

    //  MARK: Drag-and-drop Components
    private func addComponents(
        _ comps: [TransferableComponent],
        at point: CGPoint
    ) {
        let pos = canvasManager.snap(point)

        let instances = projectManager.selectedDesign?.componentInstances ?? []
        var nextRef: [UUID: Int] = instances.reduce(into: [:]) { dict, inst in
            dict[inst.componentUUID] = max(dict[inst.componentUUID] ?? 0, inst.referenceDesignatorIndex)
        }

        for comp in comps {
            let refNumber = (nextRef[comp.componentUUID] ?? 0) + 1
            nextRef[comp.componentUUID] = refNumber

            let symbolInst = SymbolInstance(
                symbolUUID: comp.symbolUUID,
                position: pos,
                cardinalRotation: .east
            )

            // This initializer now correctly uses `propertyInstances`.
            let instance = ComponentInstance(
                componentUUID: comp.componentUUID,
                propertyInstances: [],
                symbolInstance: symbolInst,
                footprintInstance: nil,
                reference: refNumber
            )

            projectManager.selectedDesign?.componentInstances.append(instance)
        }

        document.updateChangeCount(.changeDone)
        rebuildCanvasElements()
    }

    //  MARK: Build Canvas Model (Resolver)
    private func rebuildCanvasElements() {
        let designComponents = projectManager.designComponents
        var updatedElements: [CanvasElement] = []
        var existingElements = canvasElements.reduce(into: [UUID: CanvasElement]()) {
            if case .symbol(let s) = $1 { $0[s.id] = .symbol(s) }
        }

        for dc in designComponents {
            let instanceID = dc.instance.id
            
            let resolvedProperties = PropertyResolver.resolve(from: dc.definition, and: dc.instance)
            
            if var existingElement = existingElements.removeValue(forKey: instanceID),
               case .symbol(var symbol) = existingElement {
                
                var needsTextResolution = false
                if symbol.instance != dc.instance.symbolInstance {
                    symbol.instance = dc.instance.symbolInstance
                    needsTextResolution = true
                }
                if symbol.reference != dc.referenceDesignator {
                    symbol.reference = dc.referenceDesignator
                    needsTextResolution = true
                }

                if symbol.properties != resolvedProperties {
                    symbol.properties = resolvedProperties
                    needsTextResolution = true
                }
                
                if needsTextResolution {
                    symbol.resolveAnchoredTexts()
                }
                
                updatedElements.append(.symbol(symbol))
                
            } else {
                let newSymbolElement = SymbolElement(
                    id: instanceID,
                    instance: dc.instance.symbolInstance,
                    symbol: dc.definition.symbol!,
                    reference: dc.referenceDesignator,
                    properties: resolvedProperties
                )
                updatedElements.append(.symbol(newSymbolElement))
            }
        }
        
        canvasElements = updatedElements
    }

    // MARK: Sync back to Data Model (Committer)
    private func syncCanvasToModel(_ elements: [CanvasElement]) {
        let symbolElements = elements.compactMap { element -> SymbolElement? in
            if case .symbol(let symbol) = element { return symbol }
            return nil
        }

        var insts = projectManager.componentInstances
        let keepIDs = Set(symbolElements.map(\.id))
        insts.removeAll { !keepIDs.contains($0.id) }

        for sym in symbolElements {
            guard let idx = insts.firstIndex(where: { $0.id == sym.id }) else { continue }
            
            let instance = insts[idx]
            
            // Sync geometry (position & rotation)
            instance.symbolInstance = sym.instance
            
            // This now correctly calls the updated `update(with:)` method, completing the loop.
            for editedProperty in sym.properties {
                instance.update(with: editedProperty)
            }
        }
        
        projectManager.componentInstances = insts
        document.updateChangeCount(.changeDone)
    }
}
