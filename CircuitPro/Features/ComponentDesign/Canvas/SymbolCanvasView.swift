import SwiftUI

struct SymbolCanvasView: View {

    @Environment(CanvasManager.self)
    private var canvasManager

    @Environment(ComponentDesignManager.self) private var componentDesignManager
    
    @State private var isCollapsed: Bool = true
    
    @State private var tool: AnyCanvasTool? = AnyCanvasTool(CursorTool())

    var body: some View {

        @Bindable var symbolEditor = componentDesignManager.symbolEditor
        @Bindable var canvasManager = canvasManager

        let defaultTool = AnyCanvasTool(CursorTool())

        SplitPaneView(isCollapsed: $isCollapsed) {
            CanvasView(
                size: .constant(PaperSize.component.canvasSize()),
                magnification: $canvasManager.magnification,
                nodes: $symbolEditor.elements,
                selection: $symbolEditor.selectedElementIDs,
                tool: $symbolEditor.selectedTool.unwrapping(withDefault: defaultTool),
                renderLayers: [
                    GridRenderLayer(), // These layers can now access userInfo!
                    ElementsRenderLayer(),
                    PreviewRenderLayer()
                ],
                interactions: [
                    ToolInteraction(),
                    SelectionInteraction(),
//                    DragInteraction() // Add your other interactions here
                ]
            )
            .overlay(alignment: .leading) {
                SymbolDesignToolbarView()
                    .padding(10)
            }
        } handle: {
            HStack {
                CanvasControlView(editorType: .layout)
                Spacer()
                GridSpacingControlView()
                ZoomControlView()
            }
        } secondary: {
            Text("WIP")
        }
    }
}
