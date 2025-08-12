//
//  SchematicCanvasView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/29/25.
//

import SwiftUI
import SwiftData

struct SchematicCanvasView: View {

    var document: CircuitProjectDocument
    @State var canvasManager = CanvasManager()

    @Environment(\.projectManager)
    private var projectManager
    
    @State private var selectedTool: CanvasTool = CursorTool()
    let defaultTool: CanvasTool = CursorTool()
    
    var body: some View {
        @Bindable var bindableProjectManager = projectManager
        @Bindable var canvasManager = self.canvasManager

        CanvasView(
            size: .constant(PaperSize.component.canvasSize()),
            magnification: $canvasManager.magnification,
            nodes: $bindableProjectManager.canvasNodes,
            selection: $bindableProjectManager.selectedComponentIDs,
            tool: $selectedTool.unwrapping(withDefault: defaultTool),
            environment: canvasManager.environment,
            renderLayers: [
                GridRenderLayer(),
                SheetRenderLayer(),
                ElementsRenderLayer(),
                PreviewRenderLayer(),
                MarqueeRenderLayer(),
                CrosshairsRenderLayer()
            ],
            interactions: [
                KeyCommandInteraction(),
                ToolInteraction(),
                SelectionInteraction(),
                DragInteraction(),
                MarqueeInteraction()
            ],
            inputProcessors: [ GridSnapProcessor() ],
            snapProvider: CircuitProSnapProvider(),
            registeredDraggedTypes: [.transferableComponent],
            onPasteboardDropped: handleComponentDrop,
            onModelDidChange: { self.document.updateChangeCount(.changeDone) }
        )
        .onCanvasChange { context in
            canvasManager.mouseLocation = context.processedMouseLocation ?? .zero
        }
        .overlay(alignment: .leading) {
            SchematicToolbarView(selectedSchematicTool: $selectedTool)
                .padding(16)
        }
        .onAppear(perform: projectManager.rebuildCanvasNodes)
        .onChange(of: projectManager.designComponents) {
             // When the underlying data model changes, just tell the manager to rebuild.
            projectManager.rebuildCanvasNodes()
        }
        .onChange(of: projectManager.canvasNodes) {
            // This is the sync back from Canvas -> ProjectManager
            syncProjectManagerFromNodes()
        }
    }
    
    private func syncProjectManagerFromNodes() {
        let nodeIDs = Set(projectManager.canvasNodes.map(\.id))
        let missingComponentIDs = Set(projectManager.designComponents.map(\.id)).subtracting(nodeIDs)

        if !missingComponentIDs.isEmpty {
            for componentID in missingComponentIDs {
                projectManager.schematicGraph.releasePins(for: componentID)
            }
            projectManager.selectedDesign?.componentInstances.removeAll { missingComponentIDs.contains($0.id) }
            document.updateChangeCount(.changeDone)
        }
    }
    
    /// Handles dropping a new component onto the canvas from a library.
    private func handleComponentDrop(pasteboard: NSPasteboard, location: CGPoint) -> Bool {
        guard let data = pasteboard.data(forType: .transferableComponent),
              let transferable = try? JSONDecoder().decode(TransferableComponent.self, from: data) else {
            return false
        }
        
        let fetchDescriptor = FetchDescriptor<Component>(predicate: #Predicate { $0.uuid == transferable.componentUUID })
        guard let componentDefinition = (try? projectManager.modelContext.fetch(fetchDescriptor))?.first,
              let symbolDefinition = componentDefinition.symbol else {
            return false
        }
        
        let instances = projectManager.componentInstances
        let nextRefIndex = (instances.filter { $0.componentUUID == componentDefinition.uuid }.map(\.referenceDesignatorIndex).max() ?? 0) + 1
        
        let newSymbolInstance = SymbolInstance(
            symbolUUID: symbolDefinition.uuid,
            position: location,
            cardinalRotation: .east
        )
        let newComponentInstance = ComponentInstance(
            componentUUID: componentDefinition.uuid,
            propertyInstances: [],
            symbolInstance: newSymbolInstance,
            footprintInstance: nil,
            reference: nextRefIndex
        )
        
        projectManager.selectedDesign?.componentInstances.append(newComponentInstance)
        
        // Sync the graph model for the new component.
        projectManager.schematicGraph.syncPins(
            for: newSymbolInstance,
            of: symbolDefinition,
            ownerID: newComponentInstance.id
        )
        
        document.updateChangeCount(.changeDone)
        
        return true
    }
}

