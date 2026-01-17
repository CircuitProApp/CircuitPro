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
    private let wireEngine = WireEngine()

    var body: some View {

        CanvasView(
            tool: $editorSession.schematicController.selectedTool.unwrapping(
                withDefault: CursorTool()),
            items: $editorSession.schematicController.items,
            selectedIDs: $editorSession.selectedItemIDs,
            environment: canvasManager.environment,
            inputProcessors: [GridSnapProcessor()],
            snapProvider: CircuitProSnapProvider(),
            registeredDraggedTypes: [.transferableComponent],
            onPasteboardDropped: handleComponentDrop
        ) {
            GridView()
            DrawingSheetRL()

            SchematicView(engine: wireEngine)
            MarqueeView()
            CrosshairsView()
        }
        .viewport($canvasManager.viewport)
        .ignoresSafeArea()
        .overlay {
            CanvasOverlayView {
                SchematicToolbarView(
                    selectedSchematicTool: $editorSession.schematicController.selectedTool,
                    wireEngine: wireEngine
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
