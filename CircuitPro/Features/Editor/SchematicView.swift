import SwiftUI
import SwiftData

struct SchematicView: View {

    // ─────────────────────────────────────────────  injected objects
    var document: CircuitProjectDocument
    var canvasManager = CanvasManager()

    @Environment(\.modelContext)      private var modelContext
    @Environment(\.projectManager)    private var projectManager

    // ─────────────────────────────────────────────  canvas state
    @State private var canvasElements: [CanvasElement] = []
    @State private var selectedIDs:   Set<UUID>       = []
    @State private var selectedTool:  AnyCanvasTool   = .init(CursorTool())

    @State private var selectedLayer:     LayerKind?
    @State private var layerAssignments: [UUID: LayerKind] = [:]

    // ─────────────────────────────────────────────  view
    var body: some View {
        CanvasView(manager:          canvasManager,
                   elements:         $canvasElements,
                   selectedIDs:      $selectedIDs,
                   selectedTool:     $selectedTool,
                   selectedLayer:    $selectedLayer,
                   layerAssignments: $layerAssignments)

            .dropDestination(for: TransferableComponent.self) { dropped, loc in
                addComponents(dropped, atClipPoint: loc)
                return !dropped.isEmpty
            }
        

            .overlay(alignment: .leading) {
                SchematicToolbarView(selectedSchematicTool: $selectedTool)
                    .padding(16)
            }

            .onAppear { rebuildCanvasElements() }

            // If the list of instances in the design changes -> rebuild
            .onChange(of: projectManager.selectedDesign?.componentInstances) { _ in
                rebuildCanvasElements()
            }

            // If the user moves a symbol on the canvas -> write back position
            .onChange(of: canvasElements) { syncCanvasToModel($0) }
    }

    // ════════════════════════════════════════════════════════════════════
    // MARK: –  Component drop
    // ════════════════════════════════════════════════════════════════════
    private func addComponents(_ comps: [TransferableComponent],
                               atClipPoint clipPoint: CGPoint)
    {
        let origin = canvasManager.scrollOrigin
        let zoom   = canvasManager.magnification
        let docPt  = CGPoint(x: origin.x + clipPoint.x / zoom,
                             y: origin.y + clipPoint.y / zoom)
        let pos    = canvasManager.snap(docPt)

        for comp in comps {
            let symbolInst = SymbolInstance(symbolUUID: comp.symbolUUID,
                                            position  : pos,
                                            cardinalRotation: .deg0)

            let instance = ComponentInstance(componentUUID   : comp.componentUUID,
                                             properties      : comp.properties,
                                             symbolInstance  : symbolInst,
                                             footprintInstance: nil)

            projectManager.selectedDesign?.componentInstances.append(instance)
        }

        document.updateChangeCount(.changeDone)
        rebuildCanvasElements()           // show what we just added
    }

    // ════════════════════════════════════════════════════════════════════
    // MARK: –  Build CanvasElement array
    // ════════════════════════════════════════════════════════════════════
    private func rebuildCanvasElements() {
        guard let instances = projectManager.selectedDesign?.componentInstances
        else { canvasElements = []; return }

        // 1. Fetch all required library symbols with ONE SwiftData call
        let neededUUIDs = Set(instances.map { $0.symbolInstance.symbolUUID })
        let symbols     = fetchSymbols(for: neededUUIDs)
        let symDict     = Dictionary(uniqueKeysWithValues: symbols.map { ($0.uuid, $0) })

        // 2. Map each instance → SymbolElement → CanvasElement.symbol
        canvasElements = instances.compactMap { inst in
            guard let libSym = symDict[inst.symbolInstance.symbolUUID] else { return nil }
            let elem = SymbolElement(id:       inst.id,
                                     instance: inst.symbolInstance,
                                     symbol:   libSym)
            return .symbol(elem)
        }      
    }

    // ════════════════════════════════════════════════════════════════════
    // MARK: –  Push canvas edits back into the data-model
    // ════════════════════════════════════════════════════════════════════
    private func syncCanvasToModel(_ elems: [CanvasElement]) {
        guard var compInsts = projectManager.selectedDesign?.componentInstances
        else { return }

        for el in elems {
            guard case .symbol(let symEl) = el else { continue }
            if let idx = compInsts.firstIndex(where: { $0.id == symEl.id }) {
                compInsts[idx].symbolInstance.position  = symEl.instance.position
                compInsts[idx].symbolInstance.rotation  = symEl.instance.rotation
            }
        }
        document.updateChangeCount(.changeDone)
    }

    // ════════════════════════════════════════════════════════════════════
    // MARK: –  Symbol fetch helper
    // ════════════════════════════════════════════════════════════════════
    private func fetchSymbols(for uuids: Set<UUID>) -> [Symbol] {
        guard !uuids.isEmpty else { return [] }
        let request = FetchDescriptor<Symbol>(predicate: #Predicate { uuids.contains($0.uuid) })
        return (try? modelContext.fetch(request)) ?? []
    }
}
