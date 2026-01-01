import SwiftUI

struct LayoutCanvasView: View {
    @BindableEnvironment(\.projectManager)
    private var projectManager

    @Bindable var canvasManager: CanvasManager

    var body: some View {
        CanvasView(
            viewport: $canvasManager.viewport,
            store: projectManager.layoutController.canvasStore,
            tool: $projectManager.layoutController.selectedTool.unwrapping(
                withDefault: CursorTool()),
            graph: projectManager.layoutController.graph,
            layers: $projectManager.layoutController.canvasLayers,
            activeLayerId: $projectManager.layoutController.activeLayerId,
            environment: canvasManager.environment
                .withTraceEngine(projectManager.layoutController.traceEngine)
                .withGraphRenderProviders([
                    GraphTraceRenderAdapter()
                ])
                .withGraphHaloProviders([
                    TraceHaloProvider()
                ])
                .withGraphHitTestProviders([
                    TraceHitTestProvider()
                ]),
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
            LayoutToolbarView(selectedSchematicTool: $projectManager.layoutController.selectedTool)
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
