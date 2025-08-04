//
//  FootprintElementListView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 28.07.25.
//

import SwiftUI

struct FootprintElementListView: View {
    @Environment(ComponentDesignManager.self) private var componentDesignManager

    // Unified selection ID for any item, drives the List's native selection.
    enum OutlineItemID: Hashable {
        case layer(CanvasLayer)
        case element(UUID)
    }

    // The identifiable data model for the hierarchical list.
    struct OutlineItem: Identifiable {
        let id: OutlineItemID
        let content: Content
        let children: [OutlineItem]?
        
        enum Content {
            case layer(CanvasLayer)
            case element(any CanvasNode)
        }
    }
    
    // The List's selection state.
    @State private var selection: Set<OutlineItemID> = []
    @State private var expandedLayers: Set<CanvasLayer> = []

    private var footprintEditor: CanvasEditorManager {
        componentDesignManager.footprintEditor
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Footprint Elements")
                .font(.title3.weight(.semibold))
                .padding(10)
            
            List(selection: $selection) {
                ForEach(outlineData) { item in
                    disclosureGroupRow(for: item)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            
            DynamicTextSourceListView(editor: footprintEditor)
        }
        .onChange(of: selection) { handleSelectionChange() }
        .onChange(of: footprintEditor.selectedLayer) { syncSelectionFromManager() }
        .onChange(of: footprintEditor.selectedElementIDs) { syncSelectionFromManager() }
        .onAppear {
            syncSelectionFromManager()
            expandedLayers = Set(outlineData.compactMap { $0.content.layerValue })
        }
    }

    
    // MARK: - View Builders

    @ViewBuilder
    private func disclosureGroupRow(for item: OutlineItem) -> some View {
        if case .layer(let layer) = item.content {
            let isExpandedBinding = Binding<Bool>(
                get: { expandedLayers.contains(layer) },
                set: { isExpanded in
                    if isExpanded {
                        expandedLayers.insert(layer)
                    } else {
                        expandedLayers.remove(layer)
                    }
                }
            )
            
            DisclosureGroup(
                isExpanded: isExpandedBinding,
                content: {
//                    ForEach(item.children ?? []) { childItem in
//                        if case .element(let element) = childItem.content {
//                            CanvasElementRowView(element: element, editor: footprintEditor)
//                                .tag(childItem.id)
//                        }
//                    }
                    Text("WIP")
                },
                label: {
                    layerRow(for: layer)
                }
            )
        }
    }


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
    
    // MARK: - Data & State Helpers

    /// Assembles the data for the hierarchical `List`.
    private var outlineData: [OutlineItem] {
        
//        let copperLayer = CanvasLayer(kind: .copper)
//        
//        let elementsByLayer = Dictionary(
//            grouping: footprintEditor.elements,
//            by: { element in
//                if case .pad = element {
//                    return copperLayer
//                } else {
//                    return footprintEditor.layerAssignments[element.id] ?? .layer0
//                }
//            }
//        )
//        
//        var orderedLayers: [CanvasLayer] = [.layer0]
//        orderedLayers.append(contentsOf: LayerKind.footprintLayers.map { CanvasLayer(kind: $0) })
//        
//        return orderedLayers.map { layer in
//            let childElements = (elementsByLayer[layer] ?? []).map { element in
//                OutlineItem(id: .element(element.id), content: .element(element), children: nil)
//            }
//            return OutlineItem(id: .layer(layer), content: .layer(layer), children: childElements)
//        }
        return []
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
        
        footprintEditor.selectedLayer = newSelectedLayer
        footprintEditor.selectedElementIDs = newSelectedElementIDs
    }
    
    private func syncSelectionFromManager() {
        var newSelection: Set<OutlineItemID> = []
        if let selectedLayer = footprintEditor.selectedLayer {
            newSelection.insert(.layer(selectedLayer))
        } else {
            footprintEditor.selectedElementIDs.forEach { newSelection.insert(.element($0)) }
        }
        
        if self.selection != newSelection {
            self.selection = newSelection
        }
    }
}

extension FootprintElementListView.OutlineItem.Content {
    var layerValue: CanvasLayer? {
        if case .layer(let layer) = self { return layer }
        return nil
    }
}
