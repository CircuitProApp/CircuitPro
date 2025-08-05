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

        // The default tool when the framework wants to set the tool to 'nil'.
        let defaultTool = AnyCanvasTool(CursorTool())

        SplitPaneView(isCollapsed: $isCollapsed) {
            CanvasView(
                size: .constant(PaperSize.component.canvasSize()),
                magnification: $canvasManager.magnification,
                nodes: $symbolEditor.elements,
                selection: $symbolEditor.selectedElementIDs,
                tool: $symbolEditor.selectedTool.unwrapping(withDefault: defaultTool),
                
                // You can now define application-specific data to pass to your layers
  
                
                renderLayers: [
                    GridRenderLayer(), // These layers can now access userInfo!
                    ElementsRenderLayer(),
                    PreviewRenderLayer()
                ],
                interactions: [
                    ToolInteraction(),
                    SelectionInteraction(),
//                    DragInteraction() // Add your other interactions here
                ],
                userInfo: [
                    "snapGridSize": canvasManager.gridSpacing.rawValue * 10,
                    "isSnappingEnabled": canvasManager.enableSnapping
                ],
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
