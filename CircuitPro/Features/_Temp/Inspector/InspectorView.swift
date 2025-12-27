//
//  InspectorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/13/25.
//

import SwiftUI

struct InspectorView: View {

    @BindableEnvironment(\.projectManager) private var projectManager

    @State private var selectedTab: InspectorTab = .attributes

    private var singleSelectedID: UUID? {
        guard projectManager.selectedNodeIDs.count == 1 else { return nil }
        return projectManager.selectedNodeIDs.first
    }

    private var activeGraph: CanvasGraph? {
        switch projectManager.selectedEditor {
        case .schematic:
            return projectManager.schematicController.graph
        case .layout:
            return projectManager.layoutController.graph
        }
    }

    private var selectedGraphID: NodeID? {
        guard let selectedID = singleSelectedID,
              let graph = activeGraph else { return nil }
        let nodeID = NodeID(selectedID)
        return graph.hasAnyComponent(for: nodeID) ? nodeID : nil
    }

    /// A computed property that finds the ComponentInstance for a selected schematic symbol.
    private var selectedSymbolContext: (component: ComponentInstance, symbol: Binding<GraphSymbolComponent>)? {
        guard projectManager.selectedEditor == .schematic,
              let nodeID = selectedGraphID,
              let symbolBinding = projectManager.schematicController.symbolBinding(for: nodeID.rawValue),
              let componentInstance = projectManager.componentInstances.first(where: { $0.id == nodeID.rawValue })
        else { return nil }

        return (componentInstance, symbolBinding)
    }

    /// A computed property that finds the ComponentInstance for a selected layout footprint.
    private var selectedFootprintContext: (component: ComponentInstance, footprint: Binding<GraphFootprintComponent>)? {
        guard projectManager.selectedEditor == .layout,
              let nodeID = selectedGraphID,
              let footprintBinding = projectManager.layoutController.footprintBinding(for: nodeID.rawValue),
              let componentInstance = projectManager.componentInstances.first(where: { $0.id == nodeID.rawValue })
        else { return nil }

        return (componentInstance, footprintBinding)
    }

    private var selectedTextBinding: Binding<GraphTextComponent>? {
        guard let nodeID = selectedGraphID else { return nil }
        switch projectManager.selectedEditor {
        case .schematic:
            return projectManager.schematicController.textBinding(for: nodeID.rawValue)
        case .layout:
            return projectManager.layoutController.textBinding(for: nodeID.rawValue)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch projectManager.selectedEditor {

            case .schematic:
                schematicInspectorView

            case .layout:
                layoutInspectorView
            }
        }
    }

    /// The view content to display when the Schematic editor is active.
    @ViewBuilder
    private var schematicInspectorView: some View {
        if let context = selectedSymbolContext {
            SymbolNodeInspectorHostView(
                component: context.component,
                symbol: context.symbol,
                selectedTab: $selectedTab
            )
            .id(context.component.id)

        } else if let textBinding = selectedTextBinding {
            GraphTextInspectorView(text: textBinding)

        } else {
            selectionStatusView
        }
    }

    /// The view content to display when the Layout editor is active.
    @ViewBuilder
    private var layoutInspectorView: some View {
        if let context = selectedFootprintContext {
            FootprintNodeInspectorView(
                component: context.component,
                footprint: context.footprint
            )
            .id(context.component.id)

        } else if let selection = projectManager.layoutController.singleSelectedPrimitive,
                  let binding = projectManager.layoutController.primitiveBinding(for: selection.id.rawValue) {
            ScrollView {
                PrimitivePropertiesView(primitive: binding)
            }
        } else if let textBinding = selectedTextBinding {
            GraphTextInspectorView(text: textBinding)

        } else {
            selectionStatusView
        }
    }

    /// A shared view for displaying the current selection status (none, or multiple).
    @ViewBuilder
    private var selectionStatusView: some View {
        VStack {
            Spacer()
            Text(projectManager.selectedNodeIDs.isEmpty ? "No Selection" : "Multiple Items Selected")
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

extension Array where Element == BaseNode {
    func findNode(with id: UUID) -> BaseNode? {
        for node in self {
            if node.id == id {
                return node
            }
            if let foundInChildren = node.children.findNode(with: id) {
                return foundInChildren
            }
        }
        return nil
    }
}
