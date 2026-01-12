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

    var body: some View {

        CanvasView(
            viewport: $canvasManager.viewport,
            tool: $footprintEditor.selectedTool.unwrapping(withDefault: CursorTool()),
            items: $footprintEditor.items,
            selectedIDs: $footprintEditor.selectedElementIDs,
            layers: $footprintEditor.layers,
            activeLayerId: $footprintEditor.activeLayerId,
            environment: canvasManager.environment.withDefinitionTextResolver { definition in
                footprintEditor.resolveText(definition)
            },
            renderViews: [
                GridRL(),
                AxesView(),
                DrawingSheetRL(),
                DesignView(),
                HandlesRL(),
                MarqueeRL(),
                CrosshairsView(),
            ],
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
        )
        .onCanvasChange { context in
            canvasManager.mouseLocation = context.processedMouseLocation ?? .zero
        }
        .ignoresSafeArea()
        .overlay {
            CanvasOverlayView {
                FootprintDesignToolbarView()
            } status: {
                CanvasStatusView(configuration: .default)
            }
        }
    }
}
