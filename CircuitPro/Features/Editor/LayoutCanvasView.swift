import SwiftUI

struct LayoutCanvasView: View {
    @BindableEnvironment(\.projectManager)
    private var projectManager

    @BindableEnvironment(\.editorSession)
    private var editorSession

    @Bindable var canvasManager: CanvasManager

    var body: some View {
        let layoutController = editorSession.layoutController
        let selectedTool = Binding(
            get: { layoutController.selectedTool },
            set: { layoutController.selectedTool = $0 }
        )
        let layers = Binding(
            get: { layoutController.canvasLayers },
            set: { layoutController.canvasLayers = $0 }
        )
        let activeLayerId = Binding(
            get: { layoutController.activeLayerId },
            set: { layoutController.activeLayerId = $0 }
        )

        CanvasView(
            viewport: $canvasManager.viewport,
            store: layoutController.canvasStore,
            tool: selectedTool.unwrapping(
                withDefault: CursorTool()),
            graph: layoutController.graph,
            layers: layers,
            activeLayerId: activeLayerId,
            connections: layoutController.traceEngine,
            environment: canvasManager.environment,
            renderLayers: [
                GridRenderLayer(),
                SheetRenderLayer(),
                ElementsRenderLayer(),
                PreviewRenderLayer(),
                HandlesRenderLayer(),
                MarqueeRenderLayer(),
                CrosshairsRenderLayer(),
            ],
            interactions: [
                HoverHighlightInteraction(),
                KeyCommandInteraction(),
                HandleInteraction(),
                ToolInteraction(),
                SelectionInteraction(),
                DragInteraction(),
                MarqueeInteraction(),
            ],
            inputProcessors: [GridSnapProcessor()],
            snapProvider: CircuitProSnapProvider(),
            registeredDraggedTypes: [.transferablePlacement],
            onPasteboardDropped: handlePlacementDrop
        )
        .onCanvasChange { context in
            canvasManager.mouseLocation = context.processedMouseLocation ?? .zero
        }
        .overlay(alignment: .leading) {
            LayoutToolbarView(
                selectedSchematicTool: selectedTool,
                traceEngine: layoutController.traceEngine
            )
                .padding(16)
        }
    }

    private func handlePlacementDrop(pasteboard: NSPasteboard, location: CGPoint) -> Bool {
        guard let data = pasteboard.data(forType: .transferablePlacement),
            let transferable = try? JSONDecoder().decode(TransferablePlacement.self, from: data)
        else {
            return false
        }

        projectManager.placeComponent(
            instanceID: transferable.componentInstanceID,
            at: location,
            on: .front
        )

        return true
    }
}
