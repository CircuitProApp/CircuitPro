import SwiftUI
import SwiftData

struct SchematicView: View {
    
    var document: CircuitProjectDocument
    
    var canvasManager: CanvasManager = CanvasManager()
    
    @Environment(\.modelContext)
    private var modelContext
    
    @Environment(\.projectManager)
    private var projectManager
    
    @State private var canvasElements: [CanvasElement] = []
    @State private var selectedIDs: Set<UUID> = []
    @State private var selectedTool: AnyCanvasTool = .init(CursorTool())
    
    @State private var selectedLayer: LayerKind?
    @State private var layerAssignments: [UUID: LayerKind] = [:]

    var body: some View {
        CanvasView(manager: canvasManager, elements: $canvasElements, selectedIDs: $selectedIDs, selectedTool: $selectedTool, selectedLayer: $selectedLayer, layerAssignments: $layerAssignments)
            .dropDestination(for: TransferableComponent.self) { dropped, location in

                // 1. convert clip-space → document-space
                let origin = canvasManager.scrollOrigin
                let zoom   = canvasManager.magnification

                let documentPoint = CGPoint(
                    x: origin.x + location.x / zoom,
                    y: origin.y + location.y / zoom
                )

                // 2. snap if the option is enabled
                let snappedPoint = canvasManager.snap(documentPoint)

                // 3. create the instances
                dropped.forEach { addComponent($0, at: snappedPoint) }
                
                print("clip-space:", location)
                print("scroll origin:", origin)
                print("zoom:", zoom)
                print("document-space:", snappedPoint)


                return !dropped.isEmpty
            }



            .overlay(alignment: .leading) {
                SymbolDesignToolbarView()
                    .padding(16)
            }
            .onAppear {
                fetchSymbolsFromInstances()
            }
    }
    
    private func addComponent(_ comp: TransferableComponent,
                                 at location: CGPoint)
       {

           let symbolInstance = SymbolInstance(symbolUUID: comp.symbolUUID,
                                               position  : location,
                                               rotation  : 0)

           // 3. Build the ComponentInstance
           let instance = ComponentInstance(
               componentUUID   : comp.componentUUID,
               properties      : comp.properties,
               symbolInstance  : symbolInstance,
               footprintInstance: nil
           )

           // 4. Insert into the design model
           projectManager.selectedDesign?.componentInstances.append(instance)
           // 5. Let NSDocument know that the file is dirty
           document.updateChangeCount(.changeDone)
       }
    
    private func fetchSymbolsFromInstances() {
        guard let componentInstances = projectManager.selectedDesign?.componentInstances else {
            print("No component instances found")
            return
        }

        // 1. Extract the unique symbolUUIDs from SymbolInstances
        let uniqueSymbolUUIDs = Set(componentInstances.map { $0.symbolInstance.symbolUUID })
        print("Unique Symbol UUIDs: \(uniqueSymbolUUIDs)")

        // 2. Perform a single fetch for all symbols matching those UUIDs
        let fetchedSymbols = fetchSymbols(for: uniqueSymbolUUIDs)

        // 3. Map fetched symbols to their UUIDs and use them as needed
        let symbolMap = Dictionary(uniqueKeysWithValues: fetchedSymbols.map { ($0.uuid, $0) })

        // Output the fetched results for debugging
        componentInstances.forEach { instance in
            if let symbol = symbolMap[instance.symbolInstance.symbolUUID] {
                print("Component Instance: \(instance.id)")
                print("Symbol: \(symbol.name) with UUID: \(symbol.uuid)")
            } else {
                print("No Symbol found for UUID: \(instance.symbolInstance.symbolUUID)")
            }
        }
    }

    private func fetchSymbols(for uuids: Set<UUID>) -> [Symbol] {
        // Create a batched query using a type-safe SwiftData Predicate
        guard !uuids.isEmpty else { return [] } // Avoid empty fetches

        let fetchRequest = FetchDescriptor<Symbol>(
            predicate: #Predicate { uuids.contains($0.uuid) } // Batched filter for all UUIDs
        )
        
        do {
            return try modelContext.fetch(fetchRequest)
        } catch {
            print("Error fetching symbols for UUIDs: \(error)")
            return []
        }
    }
}
//
//#Preview {
//    SchematicView()
//}
