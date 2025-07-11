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
    @State private var selectedTool: AnyCanvasTool = .init(CursorTool())

    @State private var debugString: String?

    @State private var showDebugPanel: Bool = true

    
    var body: some View {
        @Bindable var bindableProjectManager = projectManager

        CanvasView(
            manager: canvasManager,
            elements: $canvasElements,
            selectedIDs: $bindableProjectManager.selectedComponentIDs,
            selectedTool: $selectedTool
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
            VStack(spacing: 5) {
                HStack {
                    Spacer()
 
                    Button {
                        showDebugPanel.toggle()
                    } label: {
                        Image(systemName: "chevron.compact.down")
                    }
                    .buttonStyle(.borderedProminent)
                }
         
                if showDebugPanel {
                    VStack(spacing: 0) {
                        ScrollView(.vertical) {
                            Text(debugString ?? "No connection elements")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                        }
                        
                    }
                    .frame(height: 200)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray))
             

                }
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
        let connections = canvasElements.compactMap { element -> String? in
            guard case .connection(let connectionElement) = element else { return nil }
            let idString = "Connection ID: \(connectionElement.id.uuidString)"

            let edgeLines = connectionElement.graph.edges.map { (id, edge) in
                "   Edge \(id)"
            }.joined(separator: "\n")
            
            let vertexLines = connectionElement.graph.vertices.map { (id, vertex) in
                "       Vertex: (\(vertex.point.x), \(vertex.point.y))"
            }.joined(separator: "\n")

            return "\(idString)\n\(edgeLines)\n\(vertexLines)"
        }

        guard !connections.isEmpty else { return nil }
        return connections.joined(separator: "\n\n") // separates each connection with a blank line
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

    /// Builds [CanvasElement] from the project manager's data model.
    private func rebuildCanvasElements() {
        // 1. Rebuild SymbolElements from ComponentInstances
        let symbolElements = projectManager.designComponents.map { designComponent -> CanvasElement in
            let elem = SymbolElement(
                id: designComponent.instance.id,
                instance: designComponent.instance.symbolInstance,
                symbol: designComponent.definition.symbol! // already prefetched
            )
            return .symbol(elem)
        }

        // 2. Rebuild ConnectionElements from Wires
        let connectionElements = projectManager.wires.map { wire -> CanvasElement in
            let graph = ConnectionGraph()
            for segment in wire.segments {
                let startPoint = resolveAttachmentPoint(segment.start)
                let endPoint = resolveAttachmentPoint(segment.end)

                let startVertex = graph.ensureVertex(at: startPoint)
                let endVertex = graph.ensureVertex(at: endPoint)
                graph.addEdge(from: startVertex.id, to: endVertex.id)
            }
            graph.simplifyCollinearSegments()
            let connElement = ConnectionElement(id: wire.id, graph: graph)
            return .connection(connElement)
        }

        // 3. Combine and update the canvas
        canvasElements = symbolElements + connectionElements
    }

    /// Resolves an AttachmentPoint from the data model into a world-space CGPoint for drawing.
    private func resolveAttachmentPoint(_ attachment: AttachmentPoint) -> CGPoint {
        switch attachment {
        case .free(let point):
            return point
        case .pin(let componentInstanceID, let pinID):
            // Find the component instance and its definition
            guard let component = projectManager.designComponents.first(where: { $0.instance.id == componentInstanceID }),
                  let symbol = component.definition.symbol,
                  let pin = symbol.pins.first(where: { $0.id == pinID })
            else {
                // This should not happen in a valid document. Return a default point.
                return .zero
            }
            // Calculate the pin's world position
            return component.instance.symbolInstance.position + pin.position.rotated(by: component.instance.symbolInstance.rotation)
        }
    }

    private func syncCanvasToModel(_ elements: [CanvasElement]) {
        // --- Sync ComponentInstances ---
        let symbolElements = elements.compactMap { element -> SymbolElement? in
            if case .symbol(let symbol) = element { return symbol }
            return nil
        }
        var compInsts = projectManager.componentInstances
        let remainingSymbolIDs = Set(symbolElements.map(\.id))
        compInsts.removeAll { !remainingSymbolIDs.contains($0.id) }

        for symbolElement in symbolElements {
            if let idx = compInsts.firstIndex(where: { $0.id == symbolElement.id }) {
                compInsts[idx].symbolInstance.position = symbolElement.instance.position
                compInsts[idx].symbolInstance.cardinalRotation = symbolElement.instance.cardinalRotation
            }
        }
        projectManager.componentInstances = compInsts

        // --- Sync Wires ---
        let connectionElements = elements.compactMap { element -> ConnectionElement? in
            if case .connection(let connection) = element { return connection }
            return nil
        }
        var newWires: [Wire] = []

        for connElement in connectionElements {
            var segments: [WireSegment] = []
            for edge in connElement.graph.edges.values {
                guard let startVertex = connElement.graph.vertices[edge.start],
                      let endVertex = connElement.graph.vertices[edge.end] else { continue }

                let startAttachment = resolvePointToAttachment(startVertex.point, in: symbolElements)
                let endAttachment = resolvePointToAttachment(endVertex.point, in: symbolElements)

                let segment = WireSegment(id: edge.id, start: startAttachment, end: endAttachment)
                segments.append(segment)
            }
            if !segments.isEmpty {
                newWires.append(Wire(id: connElement.id, segments: segments))
            }
        }
        projectManager.wires = newWires

        document.updateChangeCount(.changeDone)
    }

    /// Resolves a world-space CGPoint from the canvas back into a semantic AttachmentPoint for saving.
    private func resolvePointToAttachment(_ point: CGPoint, in symbolElements: [SymbolElement]) -> AttachmentPoint {
        for symbolElement in symbolElements {
            for pin in symbolElement.symbol.pins {
                let pinPos = symbolElement.instance.position + pin.position.rotated(by: symbolElement.instance.rotation)
                if hypot(point.x - pinPos.x, point.y - pinPos.y) < 0.01 {
                    return .pin(componentInstanceID: symbolElement.id, pinID: pin.id)
                }
            }
        }
        return .free(point: point)
    }
}
