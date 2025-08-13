import SwiftUI

struct SymbolCanvasView: View {

    @Environment(CanvasManager.self)
    private var canvasManager

    @Environment(ComponentDesignManager.self) private var componentDesignManager
    
    @State private var isCollapsed: Bool = true
    
    @State private var tool: CanvasTool? = CursorTool()

    var body: some View {

        @Bindable var symbolEditor = componentDesignManager.symbolEditor
        @Bindable var canvasManager = canvasManager

        let defaultTool = CursorTool()

        SplitPaneView(isCollapsed: $isCollapsed) {
            CanvasView(
                viewport: $canvasManager.viewport,
                nodes: $symbolEditor.canvasNodes,
                selection: $symbolEditor.selectedElementIDs,
                tool: $symbolEditor.selectedTool.unwrapping(withDefault: defaultTool),
                environment: canvasManager.environment,
                renderLayers: [
                    GridRenderLayer(),
                    AxesRenderLayer(),
                    SheetRenderLayer(),
                    ElementsRenderLayer(),
                    PreviewRenderLayer(),
                    HandlesRenderLayer(),
                    MarqueeRenderLayer(),
                    CrosshairsRenderLayer()
                ],
                interactions: [
                    KeyCommandInteraction(),
                    HandleInteraction(),
                    ToolInteraction(),
                    SelectionInteraction(),
                    DragInteraction(),
                    MarqueeInteraction()
                ],
                inputProcessors: [
                    GridSnapProcessor()
                ],
                snapProvider: CircuitProSnapProvider()
            )
            .overlay(alignment: .leading) {
                SymbolDesignToolbarView()
                    .padding(10)
            }
        } handle: {
            HStack {
                SnappingControlView()
                Spacer()
                GridSpacingControlView()
                ZoomControlView()
            }
        } secondary: {
            Text("WIP")
        }
    }
}
