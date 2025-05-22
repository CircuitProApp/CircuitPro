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
            List(
                LayerKind.footprintLayers,
                id: \.self,
                selection: $bindableComponentDesignManager.selectedFootprintLayer
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
