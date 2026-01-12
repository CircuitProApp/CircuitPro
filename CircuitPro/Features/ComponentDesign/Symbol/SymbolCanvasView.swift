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

    var body: some View {
            CanvasView(
                items: $symbolEditor.items,
                selectedIDs: $symbolEditor.selectedElementIDs,
                interactions: [
                    // HoverHighlightInteraction(),
                    // KeyCommandInteraction(),
                    // HandleInteraction(),
                    // SelectionInteraction(),
                    // DragInteraction(),
                    // MarqueeInteraction(),
                ],
                inputProcessors: [
                    GridSnapProcessor()
                ],
                snapProvider: CircuitProSnapProvider()
            ) {
                GridRL()
                AxesRL()
                DrawingSheetRL()
                DesignView()
                HandlesRL()
                MarqueeRL()
                CrosshairsView()
            }
            .canvasTool($symbolEditor.selectedTool.unwrapping(withDefault: CursorTool()))
            .canvasEnvironment(
                canvasManager.environment.withDefinitionTextResolver { definition in
                    symbolEditor.resolveText(definition)
                }
            )
            .viewport($canvasManager.viewport)
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
