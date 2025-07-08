//
//  LayerTypeListView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 5/9/25.
//

import SwiftUI

struct LayerTypeListView: View {

    @Environment(\.componentDesignManager)
    private var componentDesignManager

    var body: some View {
        @Bindable var bindableComponentDesignManager = componentDesignManager

        StageSidebarView {
            Text("Layers")
                .font(.headline)
        } content: {
            // Bridge ``CanvasLayer`` selection with the list of ``LayerKind`` values.
            let selection = Binding<LayerKind?>(
                get: { bindableComponentDesignManager.selectedFootprintLayer?.kind },
                set: { newValue in
                    if let newValue {
                        bindableComponentDesignManager.selectedFootprintLayer = CanvasLayer(kind: newValue)
                    } else {
                        bindableComponentDesignManager.selectedFootprintLayer = nil
                    }
                }
            )

            List(
                LayerKind.footprintLayers,
                id: \.self,
                selection: selection
            ) { layerType in
                        HStack {
                            Image(systemName: "circle.fill")
                                .foregroundStyle(layerType.defaultColor)
                            Text(layerType.label)
                    }
                        .disableAnimations()
                }
                .scrollContentBackground(.hidden)
        }
    }
}

#Preview {
    LayerTypeListView()
}
