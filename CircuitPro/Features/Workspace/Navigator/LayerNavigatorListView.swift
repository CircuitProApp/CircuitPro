//
//  LayerNavigatorListView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/14/25.
//

import SwiftUI

struct LayerNavigatorListView: View {
    @BindableEnvironment(\.projectManager) private var projectManager

    private var groupedLayers: [LayerSide: [LayerType]] {
        guard let layers = projectManager.selectedDesign?.layers else { return [:] }
        return Dictionary(grouping: layers, by: { $0.side ?? .none })
    }
    
    private var layerGroupOrder: [LayerSide] = [.front, .inner(1), .back, .none]

    var body: some View {
        if groupedLayers.isEmpty {
            ContentUnavailableView("No Design Selected", systemImage: "doc.text.magnifyingglass")
        } else {
            List {
                ForEach(layerGroupOrder.filter { groupedLayers.keys.contains($0) }, id: \.self) { side in
                    Section(header: Text(side.headerTitle)) {
                        ForEach(groupedLayers[side] ?? []) { layer in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(layer.defaultColor)
                                    .frame(width: 10, height: 10)
                                Text(layer.name)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        }
    }
}
