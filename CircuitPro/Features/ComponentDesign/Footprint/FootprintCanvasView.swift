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
            tool: $footprintEditor.selectedTool.unwrapping(withDefault: CursorTool()),
            items: $footprintEditor.items,
            selectedIDs: $footprintEditor.selectedElementIDs,
            layers: $footprintEditor.layers,
            activeLayerId: $footprintEditor.activeLayerId,
            environment: canvasManager.environment.withDefinitionTextResolver { definition in
                footprintEditor.resolveText(definition)
            },
            inputProcessors: [
                GridSnapProcessor()
            ],
            snapProvider: CircuitProSnapProvider()
        ) {
            GridView()
            AxesView()
            DrawingSheetRL()
            FootprintDesignView()
            MarqueeView()
            CrosshairsView()
        }
        .viewport($canvasManager.viewport)
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
