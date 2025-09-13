//
//  SymbolCanvasView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/13/25.
//

import SwiftUI

struct SymbolCanvasView: View {

    @BindableEnvironment(CanvasManager.self)
    private var canvasManager

    @BindableEnvironment(CanvasEditorManager.self)
    private var symbolEditor
    
    @State private var isCollapsed: Bool = true
    
    @State private var tool: CanvasTool? = CursorTool()

    var body: some View {

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
            .onCanvasChange { context in
                canvasManager.mouseLocation = context.processedMouseLocation ?? .zero
            }
            .overlay(alignment: .leading) {
                SymbolDesignToolbarView()
                    .padding(10)
            }
        } handle: {
            CanvasStatusBarView(isCollapsed: $isCollapsed, configuration: .fixedGrid)
        } secondary: {
            Text("WIP")
        }
    }
}
