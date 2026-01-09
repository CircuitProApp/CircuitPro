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

        CanvasView(
            viewport: $canvasManager.viewport,
            tool: $editorSession.schematicController.selectedTool.unwrapping(
                withDefault: CursorTool()),
            items: $editorSession.schematicController.items,
            selectedIDs: $editorSession.selectedItemIDs,
            connectionEngine: WireEngine(),
            environment: canvasManager.environment,
            renderLayers: [
                GridRenderLayer(),
                SheetRenderLayer(),
                WireRenderLayer(),
                ElementsRenderLayer(),
                PreviewRenderLayer(),
                MarqueeRenderLayer(),
                CrosshairsRenderLayer(),
            ],
            interactions: [
                HoverHighlightInteraction(),
                KeyCommandInteraction(),
                ToolInteraction(),
                SelectionInteraction(),
                DragInteraction(),
                WireDragInteraction(),
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
        .ignoresSafeArea()
        .overlay {
            CanvasOverlayView {
                SchematicToolbarView(
                    selectedSchematicTool: $editorSession.schematicController.selectedTool
                )
            } status: {
                CanvasStatusView()
            }
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

        if let newID = editorSession.schematicController.handleComponentDrop(
            from: transferable,
            at: location,
            packManager: packManager
        ) {
            editorSession.selectedItemIDs = [newID]
            return true
        }

        return false
    }
}
