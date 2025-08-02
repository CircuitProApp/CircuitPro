//
//  FootprintDesignView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 5/7/25.
//

import SwiftUI

struct FootprintDesignView: View {

    @Environment(CanvasManager.self)
    private var canvasManager

    @Environment(\.componentDesignManager)
    private var componentDesignManager
    
    @State private var isCollapsed: Bool = true

    var body: some View {
        @Bindable var footprintEditor = componentDesignManager.footprintEditor

        SplitPaneView(isCollapsed: $isCollapsed) {
            CanvasView(
                manager: canvasManager, schematicGraph: .init(),
                elements: $footprintEditor.elements,
                selectedIDs: $footprintEditor.selectedElementIDs,
                selectedTool: $footprintEditor.selectedTool,
                layerBindings: CanvasLayerBindings(
                    selectedLayer: $footprintEditor.selectedLayer,
                    layerAssignments: $footprintEditor.layerAssignments
                )
            )

            .overlay(alignment: .leading) {
     
                FootprintDesignToolbarView()
                
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
