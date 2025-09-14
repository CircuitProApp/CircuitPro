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
            // --- MODIFIED: The List now binds its selection to the project manager ---
            List(selection: $projectManager.activeLayerId) {
                ForEach(layerGroupOrder.filter { groupedLayers.keys.contains($0) }, id: \.self) { side in
                    Section(header: Text(side.headerTitle)) {
                        // ForEach now iterates over layers sorted to be traceable first
                        ForEach(sortedLayers(for: side)) { layer in
                            layerRow(for: layer)
                                // Tag each row with its ID for the selection to work.
                                .tag(layer.id)
                                // --- ADDED: Disable selection for non-traceable layers ---
                                .disabled(!layer.isTraceable)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        }
    }
    
    // --- ADDED: A custom view builder for the layer row ---
    @ViewBuilder
    private func layerRow(for layer: LayerType) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(
                    Color(layer.defaultColor)
                )
            
            Text(layer.name)
            
            Spacer()
        }
        // Visually dim non-traceable layers to guide the user.
        .opacity(layer.isTraceable ? 1.0 : 0.5)
    }
    
    // --- ADDED: Helper to sort layers within a group ---
    /// Sorts layers so that traceable (copper) layers appear first.
    private func sortedLayers(for side: LayerSide) -> [LayerType] {
        let layers = groupedLayers[side] ?? []
        return layers.sorted {
            if $0.isTraceable != $1.isTraceable {
                return $0.isTraceable // true comes before false
            }
            // If both are same traceability, sort by name
            return $0.name < $1.name
        }
    }
}
