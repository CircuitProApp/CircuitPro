//
//  SchematicCanvasView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/29/25.
//

import SwiftDataPacks
import SwiftUI

struct SchematicCanvasView: View {

    @BindableEnvironment(\.editorSession) private var editorSession
    @PackManager private var packManager

    @Bindable var canvasManager: CanvasManager

    var body: some View {
        let schematicController = editorSession.schematicController
        let selectedTool = Binding(
            get: { schematicController.selectedTool },
            set: { schematicController.selectedTool = $0 }
        )
        let itemsValue = schematicController.items
        let items = Binding<[any CanvasItem]>(
            get: { itemsValue },
            set: { _ in }
        )
        let selectedIDs = Binding<Set<UUID>>(
            get: { editorSession.selectedNodeIDs },
            set: { editorSession.selectedNodeIDs = $0 }
        )

        CanvasView(
            viewport: $canvasManager.viewport,
            store: schematicController.canvasStore,
            tool: selectedTool.unwrapping(
                withDefault: CursorTool()),
            items: items,
            selectedIDs: selectedIDs,
            graph: schematicController.graph,
            environment: canvasManager.environment,
            renderLayers: [
                GridRenderLayer(),
                SheetRenderLayer(),
                ElementsRenderLayer(),
                PreviewRenderLayer(),
                MarqueeRenderLayer(),
                CrosshairsRenderLayer(),
            ],
            interactions: [
                HoverHighlightInteraction(),
                KeyCommandInteraction(
                    wireEngine: schematicController.wireEngine,
                    deleteComponentInstances: { ids in
                        schematicController.deleteComponentInstances(ids: ids)
                    }
                ),
                ToolInteraction(),
                SelectionInteraction(),
                DragInteraction(wireEngine: schematicController.wireEngine),
                MarqueeInteraction(),
            ],
            inputProcessors: [GridSnapProcessor()],
            snapProvider: CircuitProSnapProvider(),
            registeredDraggedTypes: [.transferableComponent],
            onPasteboardDropped: handleComponentDrop
        )
        .onCanvasChange { context in
            canvasManager.mouseLocation = context.processedMouseLocation ?? .zero
        }
        .overlay(alignment: .leading) {
            SchematicToolbarView(
                selectedSchematicTool: selectedTool,
                wireEngine: schematicController.wireEngine
            )
            .padding(16)
        }
    }

    /// Handles dropping a new component onto the canvas from a library.
    /// The view's only job is to decode the data and delegate the action.
    private func handleComponentDrop(pasteboard: NSPasteboard, location: CGPoint) -> Bool {
        guard let data = pasteboard.data(forType: .transferableComponent),
            let transferable = try? JSONDecoder().decode(TransferableComponent.self, from: data)
        else {
            return false
        }

        return editorSession.schematicController.handleComponentDrop(
            from: transferable,
            at: location,
            packManager: packManager
        )
    }
}
