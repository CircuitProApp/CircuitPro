//
//  FootprintCanvasView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 5/7/25.
//

import SwiftUI

struct FootprintCanvasView: View {

    @BindableEnvironment(CanvasManager.self)
    private var canvasManager

    @BindableEnvironment(CanvasEditorManager.self)
    private var footprintEditor

    @State private var isCollapsed: Bool = true

    var body: some View {
        SplitPaneView(isCollapsed: $isCollapsed) {
            CanvasView(
                viewport: $canvasManager.viewport,
                store: footprintEditor.canvasStore,
                tool: $footprintEditor.selectedTool.unwrapping(withDefault: CursorTool()),
                graph: footprintEditor.graph,
                layers: $footprintEditor.layers,
                activeLayerId: $footprintEditor.activeLayerId,
                environment: canvasManager.environment
                    .withGraphRenderProviders([GraphTextRenderProvider()])
                    .withGraphHaloProviders([GraphTextHaloProvider()])
                    .withGraphHitTestProviders([GraphTextHitTestProvider()]),
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
                    HoverHighlightInteraction(),
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
                // The toolbar will also pick up the footprintEditor from the environment.
                FootprintDesignToolbarView()
                    .padding(10)
            }
        } handle: {
            CanvasStatusBarView(isCollapsed: $isCollapsed, configuration: .default)
        } secondary: {
            Text("WIP")
        }
    }
}
