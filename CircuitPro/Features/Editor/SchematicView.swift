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
        // Persist symbol moves back to the model
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

        // 2. Current max reference per component UUID
        let instances = projectManager.selectedDesign?.componentInstances ?? []
        var nextRef: [UUID: Int] = instances.reduce(into: [:]) { dict, inst in
            dict[inst.componentUUID] = max(dict[inst.componentUUID] ?? 0, inst.reference)
        }

        // 3. Add each dropped component
        for comp in comps {
            let refNumber = (nextRef[comp.componentUUID] ?? 0) + 1
            nextRef[comp.componentUUID] = refNumber

            let symbolInst = SymbolInstance(
                symbolUUID: comp.symbolUUID,
                position: pos,
                cardinalRotation: .east
            )

            let instance = ComponentInstance(
                componentUUID: comp.componentUUID,
                symbolInstance: symbolInst,
                footprintInstance: nil,
                reference: refNumber
            )

            projectManager.selectedDesign?.componentInstances.append(instance)
        }

        document.updateChangeCount(.changeDone)
        rebuildCanvasElements()
    }

    //  MARK: Build Canvas Model
    private func rebuildCanvasElements() {
        let designComponents = projectManager.designComponents
        var updatedElements: [CanvasElement] = []
        var existingElements = canvasElements.reduce(into: [UUID: CanvasElement]()) {
            if case .symbol(let s) = $1 { $0[s.id] = .symbol(s) }
        }

        // Iterate through the source of truth (designComponents)
        for dc in designComponents {
            let instanceID = dc.instance.id
            
            if var existingElement = existingElements.removeValue(forKey: instanceID),
               case .symbol(var symbol) = existingElement {
                
                // Element exists. Update its instance data if it has changed.
                if symbol.instance != dc.instance.symbolInstance {
                    symbol.instance = dc.instance.symbolInstance
                    // Manually trigger text resolution because we changed the whole instance
                    symbol.resolveAnchoredTexts()
                }
                updatedElements.append(.symbol(symbol))
                
            } else {
                // New element. Create it.
                let newSymbolElement = SymbolElement(
                    id: instanceID,
                    instance: dc.instance.symbolInstance,
                    symbol: dc.definition.symbol!
                )
                updatedElements.append(.symbol(newSymbolElement))
            }
        }
        
        canvasElements = updatedElements
    }

    // MARK: Sync back to SwiftData model
    private func syncCanvasToModel(_ elements: [CanvasElement]) {

        // Only symbol elements remain
        let symbolElements = elements.compactMap { element -> SymbolElement? in
            if case .symbol(let symbol) = element { return symbol }
            return nil
        }

        // Update component-instance positions & rotations
        var insts = projectManager.componentInstances
        let keepIDs = Set(symbolElements.map(\.id))
        insts.removeAll { !keepIDs.contains($0.id) }

        for sym in symbolElements {
            if let idx = insts.firstIndex(where: { $0.id == sym.id }) {
                // **FIXED**: Assign the whole instance to persist text override changes.
                insts[idx].symbolInstance = sym.instance
            }
        }
        projectManager.componentInstances = insts

        document.updateChangeCount(.changeDone)
    }
}
