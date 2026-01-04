//
//  LayerNavigatorListView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/14/25.
//

import SwiftUI

struct LayerNavigatorListView: View {
    @BindableEnvironment(\.projectManager) private var projectManager
    @BindableEnvironment(\.editorSession) private var editorSession

    private var groupedLayers: [LayerSide: [LayerType]] {
        Dictionary(grouping: projectManager.selectedDesign.layers, by: { $0.side ?? .none })
    }

    private var layerGroupOrder: [LayerSide] = [.front, .inner(1), .back, .none]

    private var isTraceToolActive: Bool {
        editorSession.layoutController.selectedTool is TraceTool
    }

    // 1) Gate selection writes so invalid IDs never land
    private var validatedSelection: Binding<UUID?> {
        Binding(
            get: { editorSession.layoutController.activeLayerId },
            set: { newValue in
                guard shouldAcceptSelection(newValue) else { return }
                editorSession.layoutController.activeLayerId = newValue
            }
        )
    }

    private func shouldAcceptSelection(_ id: UUID?) -> Bool {
        guard isTraceToolActive, let id else { return true }
        let allLayers = groupedLayers.values.flatMap { $0 }
        return allLayers.first(where: { $0.id == id })?.isTraceable ?? false
    }

    var body: some View {
        List(selection: validatedSelection) {
            ForEach(layerGroupOrder.filter { groupedLayers.keys.contains($0) }, id: \.self) { side in
                Section(header: Text(side.headerTitle)) {
                    ForEach(sortedLayers(for: side)) { layer in
                        let isDisabled = isTraceToolActive && !layer.isTraceable

                        if isDisabled {
                            // 2) No .tag on invalid rows => List cannot select them
                            // 3) Block selection + block hit testing to remove highlight/press feedback
                            layerRow(for: layer)
                                .opacity(0.5)
                                .selectionDisabled(true)     // macOS 13+/iOS 16+
                                .allowsHitTesting(false)     // prevents any click
                                .contentShape(Rectangle())   // define row shape explicitly
                        } else {
                            layerRow(for: layer)
                                .tag(layer.id)               // only valid rows are selectable
                                .selectionDisabled(false)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .onChange(of: editorSession.layoutController.selectedTool, initial: true) {
            handleToolChange()
        }
    }

    @ViewBuilder
    private func layerRow(for layer: LayerType) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color(layer.defaultColor))
            Text(layer.name)
            Spacer()
        }
    }

    private func sortedLayers(for side: LayerSide) -> [LayerType] {
        let layers = groupedLayers[side] ?? []
        return layers.sorted {
            if $0.isTraceable != $1.isTraceable {
                return $0.isTraceable
            }
            return $0.name < $1.name
        }
    }

    private func handleToolChange() {
        guard isTraceToolActive else { return }
        let allLayers = groupedLayers.values.flatMap { $0 }

        if let activeId = editorSession.layoutController.activeLayerId,
           let activeLayer = allLayers.first(where: { $0.id == activeId }),
           activeLayer.isTraceable {
            return
        }
        editorSession.layoutController.activeLayerId = allLayers.first(where: { $0.isTraceable })?.id
    }
}
