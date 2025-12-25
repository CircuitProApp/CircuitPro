//
//  SchematicCanvasView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/29/25.
//

import SwiftUI
import SwiftDataPacks

struct SchematicCanvasView: View {

    @BindableEnvironment(\.projectManager) private var projectManager
    @PackManager private var packManager

    @Bindable var canvasManager: CanvasManager

    var body: some View {
        CanvasView(
            viewport: $canvasManager.viewport,
            store: projectManager.schematicController.canvasStore,
            tool: $projectManager.schematicController.selectedTool.unwrapping(withDefault: CursorTool()),
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
            onPasteboardDropped: handleComponentDrop
        )
        .onCanvasChange { context in
            canvasManager.mouseLocation = context.processedMouseLocation ?? .zero
        }
        .overlay(alignment: .leading) {
            SchematicToolbarView(selectedSchematicTool: $projectManager.schematicController.selectedTool)
                .padding(16)
        }
    }

    /// Handles dropping a new component onto the canvas from a library.
    /// The view's only job is to decode the data and delegate the action.
    private func handleComponentDrop(pasteboard: NSPasteboard, location: CGPoint) -> Bool {
        guard let data = pasteboard.data(forType: .transferableComponent),
              let transferable = try? JSONDecoder().decode(TransferableComponent.self, from: data) else {
            return false
        }

        return projectManager.schematicController.handleComponentDrop(
            from: transferable,
            at: location,
            packManager: packManager
        )
    }
}
