import SwiftUI
import SwiftData

struct SchematicView: View {

    // Injected
    var document: CircuitProjectDocument
    var canvasManager = CanvasManager()

    @Environment(\.projectManager)
    private var projectManager

    // Canvas state - we only need to manage the selected tool here.
    @State private var selectedTool: AnyCanvasTool = .init(CursorTool())
    
    // We no longer need @State for canvasElements or nets for this view's core logic.

    var body: some View {
        // We need a bindable version of the manager to pass its selection down.
        // This is the single source of truth for the selection's IDs.
        @Bindable var bindableProjectManager = projectManager

        CanvasView(
            manager: canvasManager,
            selectedIDs: $bindableProjectManager.selectedComponentIDs,
            selectedTool: $selectedTool,
            designComponents: projectManager.designComponents,
            schematicGraph: projectManager.schematicGraph

        )
        .overlay(alignment: .leading) {
            SchematicToolbarView(selectedSchematicTool: $selectedTool)
                .padding(16)
        }
        // NOTE: The complex .onChange modifiers for rebuilding and syncing
        // the canvas are now GONE. The CanvasController handles its own updates.
    }

    // The addComponents, rebuildCanvasElements, and syncCanvasToModel methods
    // can now be REMOVED from this file. Their logic is either obsolete or has
    // been moved into the CanvasController and its gesture helpers.
}
