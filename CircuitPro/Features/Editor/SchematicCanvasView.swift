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
            environment: canvasManager.environment.withComponentTextResolver { text, component, target in
                editorSession.projectManager.generateString(for: text, component: component)
            },
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
                KeyCommandInteraction(),
                ToolInteraction(),
                SelectionInteraction(),
                DragInteraction(),
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
                selectedSchematicTool: $editorSession.schematicController.selectedTool
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
