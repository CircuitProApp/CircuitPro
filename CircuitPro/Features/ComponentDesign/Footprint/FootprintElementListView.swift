//
//  FootprintElementListView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 28.07.25.
//

import SwiftUI

struct FootprintElementListView: View {
    @Environment(\.componentDesignManager) private var componentDesignManager

    // Unified selection ID for any item, drives the List's native selection.
    private enum OutlineItemID: Hashable {
        case layer(CanvasLayer)
        case element(UUID)
    }

    // The identifiable data model for the hierarchical list.
    private struct OutlineItem: Identifiable {
        let id: OutlineItemID
        let content: Content
        let children: [OutlineItem]? // MUST be optional for the List initializer
        
        enum Content {
            case layer(CanvasLayer)
            case element(CanvasElement)
        }
    }
    
    // The List's selection state.
    @State private var selection: Set<OutlineItemID> = []

    var body: some View {
        @Bindable var manager = componentDesignManager
        
        VStack(alignment: .leading, spacing: 0) {
            Text("Footprint Elements")
                .font(.title3.weight(.semibold))
                .padding(10)
            
            // Use the canonical hierarchical List initializer.
            List(outlineData, children: \.children, selection: $selection) { item in
                switch item.content {
                case .layer(let layer):
                    layerRow(for: layer)
                case .element(let element):
                    elementRow(for: element)
                }
            }
            // CRITICAL: .sidebar style is designed for outlines and prevents the layout shift.
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        // This is now the single source of truth for synchronizing selection.
        .onChange(of: selection) { handleSelectionChange() }
        // Sync our local state if the manager changes programmatically.
        .onChange(of: manager.selectedFootprintLayer) { syncSelectionFromManager() }
        .onChange(of: manager.selectedFootprintElementIDs) { syncSelectionFromManager() }
        .onAppear { syncSelectionFromManager() }
    }

    // MARK: - View Builders

    @ViewBuilder
    private func layerRow(for layer: CanvasLayer) -> some View {
        HStack {
            Image(systemName: "circle.fill")
                .foregroundStyle(layer.kind?.defaultColor ?? .gray)
            Text(layer.kind?.label ?? "No Layer")
                .fontWeight(.semibold)
            Spacer()
        }
    }

    @ViewBuilder
    private func elementRow(for element: CanvasElement) -> some View {
        switch element {
        case .pad(let pad):
            Label("Pad \(pad.number)", systemImage: "square.fill.on.square")
        case .primitive(let primitive):
            Label(primitive.displayName, systemImage: "path")
        default:
            EmptyView()
        }
    }
    
    // MARK: - Data & State Helpers

    /// Assembles the data for the hierarchical `List`.
    private var outlineData: [OutlineItem] {
        let elementsByLayer = Dictionary(
            grouping: componentDesignManager.footprintElements,
            by: { componentDesignManager.layerAssignments[$0.id] ?? .layer0 }
        )
        
        var orderedLayers: [CanvasLayer] = [.layer0]
        orderedLayers.append(contentsOf: LayerKind.footprintLayers.map { CanvasLayer(kind: $0) })
        
        return orderedLayers.map { layer in
            let childElements = (elementsByLayer[layer] ?? []).map { element in
                OutlineItem(id: .element(element.id), content: .element(element), children: nil)
            }
            // CRITICAL: This ensures every layer is treated as a branch, even if empty.
            return OutlineItem(id: .layer(layer), content: .layer(layer), children: childElements)
        }
    }
    
    // MARK: - Selection Synchronization Logic
    
    private func handleSelectionChange() {
        var newSelectedLayer: CanvasLayer? = nil
        var newSelectedElementIDs: Set<UUID> = []

        let layerSelection = selection.first { if case .layer = $0 { return true } else { return false } }

        if let layerSelection, case .layer(let layer) = layerSelection {
            newSelectedLayer = layer
            if selection.count > 1 { self.selection = [layerSelection] }
        } else {
            newSelectedElementIDs = Set(selection.compactMap {
                if case .element(let uuid) = $0 { return uuid } else { return nil }
            })
        }
        
        componentDesignManager.selectedFootprintLayer = newSelectedLayer
        componentDesignManager.selectedFootprintElementIDs = newSelectedElementIDs
    }
    
    private func syncSelectionFromManager() {
        var newSelection: Set<OutlineItemID> = []
        if let selectedLayer = componentDesignManager.selectedFootprintLayer {
            newSelection.insert(.layer(selectedLayer))
        } else {
            componentDesignManager.selectedFootprintElementIDs.forEach { newSelection.insert(.element($0)) }
        }
        
        if self.selection != newSelection {
            self.selection = newSelection
        }
    }
}
