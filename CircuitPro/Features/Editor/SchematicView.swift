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
            manager:      canvasManager,
            schematicGraph: projectManager.schematicGraph,
            elements:     $canvasElements,
            selectedIDs:  $bindableProjectManager.selectedComponentIDs,
            selectedTool: $selectedTool,
            onComponentDropped: { component, point in
                addComponents([component], at: point)
            }
        )
        .overlay(alignment: .leading) {
            SchematicToolbarView(selectedSchematicTool: $selectedTool)
                .padding(16)
        }
        .overlay(alignment: .bottom) {
            if !nets.isEmpty {
                NetsOverlay(graph: $bindableProjectManager.schematicGraph, nets: nets)
            }
        }
        .onAppear {
            rebuildCanvasElements()
        }

        // Rebuild when the data model changes
        .onChange(of: projectManager.componentInstances) { _ in
            rebuildCanvasElements()
        }
        
        // Analyze the graph when it changes
        .onChange(of: projectManager.schematicGraph.vertices) { _, _ in updateNets() }
        .onChange(of: projectManager.schematicGraph.edges) { _, _ in updateNets() }

        // Persist symbol moves back to the model
        .onChange(of: canvasElements) { syncCanvasToModel($0) }
        
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

    // ───────────────────────────────
    //  MARK: Drag-and-drop Components
    // ───────────────────────────────
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
                position:   pos,
                cardinalRotation: .deg0
            )

            let instance = ComponentInstance(
                componentUUID:   comp.componentUUID,
                properties:      comp.properties,
                symbolInstance:  symbolInst,
                footprintInstance: nil,
                reference:       refNumber
            )

            projectManager.selectedDesign?.componentInstances.append(instance)
        }

        document.updateChangeCount(.changeDone)
        rebuildCanvasElements()
    }

    // ─────────────────────────
    //  MARK: Build Canvas Model
    // ─────────────────────────
    private func rebuildCanvasElements() {
        canvasElements = projectManager.designComponents.map { dc in
            .symbol(
                SymbolElement(
                    id:       dc.instance.id,
                    instance: dc.instance.symbolInstance,
                    symbol:   dc.definition.symbol!   // already in cache
                )
            )
        }
    }

    // ─────────────────────────────────────
    //  MARK: Sync back to SwiftData model
    // ─────────────────────────────────────
    private func syncCanvasToModel(_ elements: [CanvasElement]) {

        // Only symbol elements remain
        let symbolElements = elements.compactMap { element -> SymbolElement? in
            if case .symbol(let s) = element { return s }
            return nil
        }

        // Update component-instance positions & rotations
        var insts = projectManager.componentInstances
        let keepIDs = Set(symbolElements.map(\.id))
        insts.removeAll { !keepIDs.contains($0.id) }

        for sym in symbolElements {
            if let idx = insts.firstIndex(where: { $0.id == sym.id }) {
                insts[idx].symbolInstance.position          = sym.instance.position
                insts[idx].symbolInstance.cardinalRotation  = sym.instance.cardinalRotation
            }
        }
        projectManager.componentInstances = insts

        document.updateChangeCount(.changeDone)
    }
}
