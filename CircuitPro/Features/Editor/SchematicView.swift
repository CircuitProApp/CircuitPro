import SwiftUI
import SwiftData

struct SchematicView: View {

    // injected objects
    var document: CircuitProjectDocument
    var canvasManager = CanvasManager()

    @Environment(\.projectManager)
    private var projectManager

    // canvas state
    @State private var canvasElements: [CanvasElement] = []
    @State private var selectedIDs: Set<UUID> = []
    @State private var selectedTool: AnyCanvasTool = .init(CursorTool())

    @State private var selectedLayer: CanvasLayer?
    @State private var layerAssignments: [UUID: CanvasLayer] = [:]

    @State private var debugString: String?

    var body: some View {
        CanvasView(
            manager: canvasManager,
            elements: $canvasElements,
            selectedIDs: $selectedIDs,
            selectedTool: $selectedTool,
            layerBindings: CanvasLayerBindings(
                selectedLayer: $selectedLayer,
                layerAssignments: $layerAssignments
            )
        )
        .dropDestination(for: TransferableComponent.self) { dropped, loc in
            addComponents(dropped, atClipPoint: loc)
            return !dropped.isEmpty
        }
        .overlay(alignment: .leading) {
            SchematicToolbarView(selectedSchematicTool: $selectedTool)
                .padding(16)
        }
        .overlay(alignment: .bottomLeading) {
            VStack {
                Text(debugString ?? "No connection elements")
            }
            .padding(10)
        }
        .onAppear { rebuildCanvasElements() }
        // If the list of instances in the design changes -> rebuild
        .onChange(of: projectManager.componentInstances) { _ in
            rebuildCanvasElements()
        }
        // If the user moves a symbol on the canvas -> write back position
        .onChange(of: canvasElements) { syncCanvasToModel($0) }
        .onChange(of: canvasElements) {
            debugString = connectionElements()
        }
    }

    // 2 Connection debug
    private func connectionElements() -> String? {
        // 2.1 Filter out only the .connection cases, map to their UUID strings
        let ids = canvasElements.compactMap { element -> String? in
            if case .connection(let connectionElement) = element {
                return connectionElement.id.uuidString
            }
            return nil
        }
        // 2.2 If there are none, return nil; otherwise join them with commas (or newlines)
        guard !ids.isEmpty else { return nil }
        return ids.joined(separator: ", ")
    }

    // 1. Component drop: Add Components with Incremental Reference Number
    // Adds the dropped components and assigns a reference number that
    // increments *within each component type* (e.g. C1, C2 … R1 …).
    private func addComponents(
        _ comps: [TransferableComponent],
        atClipPoint clipPoint: CGPoint
    ) {
        // ── 1. Convert clip-space → document coordinates
        let origin = canvasManager.scrollOrigin
        let zoom = canvasManager.magnification
        let docPt = CGPoint(x: origin.x + clipPoint.x / zoom, y: origin.y + clipPoint.y / zoom)
        let pos    = canvasManager.snap(docPt)

        // ── 2. Pre-compute the current max reference *per component UUID*
        let instances = projectManager.selectedDesign?.componentInstances ?? []
        var nextRef: [UUID: Int] = instances
            .reduce(into: [:]) { dict, inst in
                dict[inst.componentUUID] = max(dict[inst.componentUUID] ?? 0, inst.reference)
            }

        // ── 3. Add each dropped component, bumping the counter only for its own UUID
        for comp in comps {
            // 3.1 Get the next number for *this* component type
            let refNumber = (nextRef[comp.componentUUID] ?? 0) + 1
            nextRef[comp.componentUUID] = refNumber        // update for multi-drop

            // 3.2 Build instances
            let symbolInst = SymbolInstance(
                symbolUUID: comp.symbolUUID,
                position: pos,
                cardinalRotation: .deg0
            )

            let instance = ComponentInstance(
                componentUUID: comp.componentUUID,
                properties: comp.properties,
                symbolInstance: symbolInst,
                footprintInstance: nil,
                reference: refNumber
            )

            projectManager.selectedDesign?.componentInstances.append(instance)
        }

        document.updateChangeCount(.changeDone)
        rebuildCanvasElements()
    }

    /// Builds [CanvasElement] from in-memory DesignComponents — no DB round-trip.
    private func rebuildCanvasElements() {
        canvasElements = projectManager.designComponents.map { designComponent in
            let elem = SymbolElement(
                id: designComponent.instance.id,
                instance: designComponent.instance.symbolInstance,
                symbol: designComponent.definition.symbol!      // already prefetched
            )
            return .symbol(elem)
        }
    }

    private func syncCanvasToModel(_ elements: [CanvasElement]) {
        guard let design = projectManager.selectedDesign else { return }

        var compInsts = design.componentInstances

        // 1 ─ delete instances that no longer have a matching element on canvas
        let remainingIDs = Set(elements.map(\.id))
        compInsts.removeAll { !remainingIDs.contains($0.id) }

        // 2 ─ update positions and rotations of the remaining instances
        for element in elements {
            guard case .symbol(let symbolElement) = element else { continue }
            if let idx = compInsts.firstIndex(where: { $0.id == symbolElement.id }) {
                compInsts[idx].symbolInstance.position = symbolElement.instance.position
                compInsts[idx].symbolInstance.cardinalRotation = symbolElement.instance.cardinalRotation
            }
        }

        design.componentInstances = compInsts
        document.updateChangeCount(.changeDone)
    }
}
