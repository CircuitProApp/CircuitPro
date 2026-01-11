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

    @State private var tool: CanvasTool? = CursorTool()

    var body: some View {

        let defaultTool = CursorTool()

            CanvasView(
                viewport: $canvasManager.viewport,
                tool: $symbolEditor.selectedTool.unwrapping(withDefault: defaultTool),
                items: $symbolEditor.items,
                selectedIDs: $symbolEditor.selectedElementIDs,
                environment: canvasManager.environment,
                renderViews: [
                    GridRL(),
                    AxesRL(),
                    DrawingSheetRL(),
                    PrimitiveRL(),
                    PreviewRL(),
                    HandlesRL(),
                    MarqueeRL(),
                    CrosshairsRL(),
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
                inputProcessors: [
                    GridSnapProcessor()
                ],
                snapProvider: CircuitProSnapProvider()
            )
            .onCanvasChange { context in
                canvasManager.mouseLocation = context.processedMouseLocation ?? .zero
            }
            .ignoresSafeArea()
            .overlay(alignment: .leading) {
                CanvasOverlayView {
                    SymbolDesignToolbarView()
                } status: {
                    CanvasStatusView(configuration: .fixedGrid)
                }
            }

    }
}
