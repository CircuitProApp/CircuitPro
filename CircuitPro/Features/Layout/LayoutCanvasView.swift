import SwiftUI

struct LayoutCanvasView: View {
    @BindableEnvironment(\.projectManager)
    private var projectManager

    @BindableEnvironment(\.editorSession)
    private var editorSession

    @Bindable var canvasManager: CanvasManager
    private let traceEngine = TraceEngine()

    var body: some View {
        CanvasView(
            tool: $editorSession.layoutController.selectedTool.unwrapping(
                withDefault: CursorTool()),
            items: $editorSession.layoutController.items,
            selectedIDs: $editorSession.selectedItemIDs,
            layers: $editorSession.layoutController.canvasLayers,
            activeLayerId: $editorSession.layoutController.activeLayerId,
            environment: canvasManager.environment
                .withTextTarget(.footprint),
            inputProcessors: [GridSnapProcessor()],
            snapProvider: CircuitProSnapProvider(),
            registeredDraggedTypes: [.transferablePlacement],
            onPasteboardDropped: handlePlacementDrop
        ) {
            GridView()
            DrawingSheetRL()
            LayoutView(traceEngine: traceEngine)
            MarqueeView()
            CrosshairsView()
        }
        .viewport($canvasManager.viewport)
        .ignoresSafeArea()
        .overlay {
            CanvasOverlayView {
                LayoutToolbarView(
                    selectedLayoutTool: $editorSession.layoutController.selectedTool,
                    traceEngine: traceEngine
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

        editorSession.selectedItemIDs = [transferable.componentInstanceID]

        return true
    }
}
