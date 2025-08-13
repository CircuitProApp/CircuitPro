//
//  FootprintCanvasView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 5/7/25.
//

import SwiftUI

struct FootprintCanvasView: View {
    
    @Environment(CanvasManager.self)
    private var canvasManager
    
    @Environment(ComponentDesignManager.self)
    private var componentDesignManager
    
    @State private var isCollapsed: Bool = true
    
    var body: some View {
        @Bindable var footprintEditor = componentDesignManager.footprintEditor
        @Bindable var manager = canvasManager
        
        SplitPaneView(isCollapsed: $isCollapsed) {
            CanvasView(
                viewport: $manager.viewport,
                nodes: $footprintEditor.canvasNodes,
                selection: $footprintEditor.selectedElementIDs,
                tool: $footprintEditor.selectedTool.unwrapping(withDefault: CursorTool()),
                layers: $footprintEditor.layers,
                activeLayerId: $footprintEditor.activeLayerId,
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
                FootprintDesignToolbarView()
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
        .onAppear {
            componentDesignManager.footprintEditor.setupForFootprintEditing()
        }
    }
}
