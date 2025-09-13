//
//  FootprintCanvasView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 5/7/25.
//

import SwiftUI

struct FootprintCanvasView: View {
    
    // Manages the global canvas state like viewport and mouse location.
    @Environment(CanvasManager.self)
    private var canvasManager
    
    // The editor for the currently *selected* footprint. This is injected
    // by the parent view (ComponentDesignStageContainerView) when a footprint is chosen.
    @Environment(CanvasEditorManager.self)
    private var footprintEditor
    
    @State private var isCollapsed: Bool = true
    
    var body: some View {
        // Bind directly to the editor from the environment.
        @Bindable var footprintEditor = footprintEditor
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
        // The .onAppear modifier is no longer necessary. The editor is configured
        // upon creation of a new Footprint instance within the ComponentDesignManager.
    }
}
