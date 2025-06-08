import SwiftUI
import SwiftData

struct SchematicView: View {
    
    var document: CircuitProjectDocument
    
    var canvasManager: CanvasManager = CanvasManager()
    @Environment(\.projectManager)
    private var projectManager
    
    @State private var canvasElements: [CanvasElement] = []
    @State private var selectedIDs: Set<UUID> = []
    @State private var selectedTool: AnyCanvasTool = .init(CursorTool())
    
    @State private var selectedLayer: LayerKind?
    @State private var layerAssignments: [UUID: LayerKind] = [:]

    var body: some View {
        CanvasView(manager: canvasManager, elements: $canvasElements, selectedIDs: $selectedIDs, selectedTool: $selectedTool, selectedLayer: $selectedLayer, layerAssignments: $layerAssignments)
            .dropDestination(for: TransferableComponent.self)
                    { droppedComponents, location in

                        for comp in droppedComponents {
                            addComponent(comp, at: location)
                        }
                        return !droppedComponents.isEmpty
                    }
            .overlay(alignment: .leading) {
                SymbolDesignToolbarView()
                    .padding(16)
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
           print(projectManager.selectedDesign == nil)
           // 5. Let NSDocument know that the file is dirty
           document.updateChangeCount(.changeDone)
       }
}
//
//#Preview {
//    SchematicView()
//}
