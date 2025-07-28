//
//  FootprintElementListView.swift
//  CircuitPro
//
//  Created by Gemini on 28.07.25.
//

import SwiftUI

struct FootprintElementListView: View {
    @Environment(\.componentDesignManager) private var componentDesignManager

    // ID for a selectable item in the outline. Can be a layer or an element.
    private enum OutlineItemID: Hashable {
        case layer(CanvasLayer)
        case element(UUID)
    }

    // A unified, identifiable item for the hierarchical list.
    private struct OutlineItem: Identifiable {
        var id: OutlineItemID {
            switch content {
            case .layer(let layer): return .layer(layer)
            case .element(let element): return .element(element.id)
            }
        }
        let content: Content
        var children: [OutlineItem]?

        enum Content {
            case layer(CanvasLayer)
            case element(CanvasElement)
        }
    }

    // This is the local selection state for the List.
    @State private var selection: Set<OutlineItemID> = []

    var body: some View {
        @Bindable var manager = componentDesignManager
        
        VStack(alignment: .leading) {
            Text("Footprint Elements")
                .font(.title2.weight(.semibold))
                .padding([.horizontal, .top])

            List(outlineData, children: \.children, selection: $selection) { item in
                switch item.content {
                case .layer(let layer):
                    layerRow(for: layer)
                case .element(let element):
                    elementRow(for: element)
                }
            }
            .listStyle(.sidebar)
        }
        .frame(minWidth: 240)
        .onChange(of: selection) {
            updateManagerFromSelection()
        }
        .onChange(of: manager.selectedFootprintElementIDs) {
            updateSelectionFromManager()
        }
        .onChange(of: manager.selectedFootprintLayer) {
            updateSelectionFromManager()
        }
        .onAppear {
            updateSelectionFromManager()
        }
    }

    // MARK: - View Builders

    @ViewBuilder
    private func layerRow(for layer: CanvasLayer) -> some View {
        HStack {
            Image(systemName: "circle.fill")
                .foregroundStyle(layer.kind?.defaultColor ?? .gray)
            Text(layer.kind?.label ?? "No Layer")
                .fontWeight(.semibold)
        }
    }

    @ViewBuilder
    private func elementRow(for element: CanvasElement) -> some View {
        switch element {
        case .pad(let pad):
            // Your Pad model might use 'number' or 'designator'. Adjust as needed.
            Label("Pad \(pad.number)", systemImage: "square.fill.on.square")
        case .primitive(let primitive):
            Label(primitive.displayName, systemImage: "path")
        default:
            EmptyView()
        }
    }
    
    // MARK: - Data & State Management

    /// Creates the hierarchical data structure for the list in a fixed order.
    private var outlineData: [OutlineItem] {
        // 1. Group existing elements by layer for efficient lookup.
        let elementsByLayer = Dictionary(
            grouping: componentDesignManager.footprintElements,
            by: { componentDesignManager.layerAssignments[$0.id] ?? .layer0 }
        )

        // 2. Create the list of layers in the desired, fixed order.
        var orderedLayers: [CanvasLayer] = []
        orderedLayers.append(.layer0) // Start with the "No Layer" option.
        orderedLayers.append(contentsOf: LayerKind.footprintLayers.map { CanvasLayer(kind: $0) })
        
        // 3. Build the final array of OutlineItems, preserving the specified order.
        return orderedLayers.map { layer in
            let childElements = elementsByLayer[layer] ?? []
            let children = childElements.map { element in
                OutlineItem(content: .element(element), children: nil)
            }
            return OutlineItem(content: .layer(layer), children: children.isEmpty ? nil : children)
        }
    }
    
    /// Updates the `ComponentDesignManager` when the local `selection` changes.
    private func updateManagerFromSelection() {
        var newSelectedLayer: CanvasLayer? = nil
        var newSelectedElementIDs: Set<UUID> = []

        let selectedLayerID = selection.first {
            if case .layer = $0 { return true } else { return false }
        }

        if let selectedLayerID, case .layer(let layer) = selectedLayerID {
            newSelectedLayer = layer
        } else {
            for itemID in selection {
                if case .element(let uuid) = itemID {
                    newSelectedElementIDs.insert(uuid)
                }
            }
        }
        
        // Prevent feedback loops by checking for actual changes before updating.
        if componentDesignManager.selectedFootprintLayer != newSelectedLayer {
            componentDesignManager.selectedFootprintLayer = newSelectedLayer
        }
        if componentDesignManager.selectedFootprintElementIDs != newSelectedElementIDs {
            componentDesignManager.selectedFootprintElementIDs = newSelectedElementIDs
        }
    }
    
    /// Updates the local `selection` when the `ComponentDesignManager` changes.
    private func updateSelectionFromManager() {
        var newSelection: Set<OutlineItemID> = []
        if let selectedLayer = componentDesignManager.selectedFootprintLayer {
            newSelection.insert(.layer(selectedLayer))
        } else {
            for elementID in componentDesignManager.selectedFootprintElementIDs {
                newSelection.insert(.element(elementID))
            }
        }
        
        if self.selection != newSelection {
            self.selection = newSelection
        }
    }
}
