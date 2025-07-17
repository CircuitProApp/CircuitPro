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

    var body: some View {
        @Bindable var bindableComponentDesignManager = componentDesignManager

        CanvasView(
            manager: canvasManager, netList: .init(),
            elements: $bindableComponentDesignManager.footprintElements,
            selectedIDs: $bindableComponentDesignManager.selectedFootprintElementIDs,
            selectedTool: $bindableComponentDesignManager.selectedFootprintTool,
            layerBindings: CanvasLayerBindings(
                selectedLayer: $bindableComponentDesignManager.selectedFootprintLayer,
                layerAssignments: $bindableComponentDesignManager.layerAssignments
            )
        )

        .overlay(alignment: .leading) {
            FootprintDesignToolbarView()
                .padding(10)
        }
        .overlay(alignment: .bottom) {
            HStack {
                CanvasControlView(editorType: .layout)
                Spacer()
                GridSpacingControlView()
                ZoomControlView()
            }
            .padding(10)
            .background(.ultraThinMaterial)

        }
        .clipAndStroke(with: .rect(cornerRadius: 20))
    }
}
