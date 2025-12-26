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

    /// A computed property that attempts to find the selected node from the currently active canvas.
    private var singleSelectedNode: BaseNode? {
        guard projectManager.selectedNodeIDs.count == 1,
              let selectedID = projectManager.selectedNodeIDs.first else {
            return nil
        }
        return projectManager.activeCanvasStore.nodes.findNode(with: selectedID)
    }

    /// A computed property that finds the ComponentInstance for a selected SymbolNode.
    private var selectedComponentContext: (component: ComponentInstance, node: SymbolNode)? {
        guard let symbolNode = singleSelectedNode as? SymbolNode else {
            return nil
        }

        if let componentInstance = projectManager.componentInstances.first(where: { $0.id == symbolNode.id }) {
            return (componentInstance, symbolNode)
        }

        return nil
    }

    /// A computed property that finds the ComponentInstance for a selected FootprintNode.
    private var selectedFootprintContext: (component: ComponentInstance, node: FootprintNode)? {
        // Ensure the selected node is a FootprintNode
        guard let footprintNode = singleSelectedNode as? FootprintNode else {
            return nil
        }

        // The FootprintNode's ID is the same as the ComponentInstance's ID.
        if let componentInstance = projectManager.componentInstances.first(where: { $0.id == footprintNode.id }) {
            return (componentInstance, footprintNode)
        }

        return nil
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
        if let context = selectedComponentContext {
            SymbolNodeInspectorHostView(
                component: context.component,
                symbolNode: context.node,
                selectedTab: $selectedTab
            )
            .id(context.component.id)

        } else if let anchoredText = singleSelectedNode as? AnchoredTextNode {
            AnchoredTextInspectorView(anchoredText: anchoredText)

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
                footprintNode: context.node
            )
            .id(context.component.id)

        } else if let selection = projectManager.layoutController.singleSelectedPrimitive,
                  let binding = projectManager.layoutController.primitiveBinding(for: selection.id.rawValue) {
            ScrollView {
                PrimitivePropertiesView(primitive: binding)
            }
        } else if let anchoredText = singleSelectedNode as? AnchoredTextNode {
            AnchoredTextInspectorView(anchoredText: anchoredText)

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
