import SwiftUI

struct LayoutCanvasView: View {
    @BindableEnvironment(\.projectManager)
    private var projectManager

    @BindableEnvironment(\.editorSession)
    private var editorSession

    @Bindable var canvasManager: CanvasManager

    var body: some View {
        CanvasView(
            viewport: $canvasManager.viewport,
            tool: $editorSession.layoutController.selectedTool.unwrapping(
                withDefault: CursorTool()),
            items: $editorSession.layoutController.items,
            selectedIDs: $editorSession.selectedItemIDs,
            layers: $editorSession.layoutController.canvasLayers,
            activeLayerId: $editorSession.layoutController.activeLayerId,
            environment: canvasManager.environment
                .withTextTarget(.footprint),
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
            CanvasOverlayView {
                LayoutToolbarView(
                    selectedLayoutTool: $editorSession.layoutController.selectedTool
                )
            } status: {
                CanvasStatusView(configuration: .default)
            }
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
