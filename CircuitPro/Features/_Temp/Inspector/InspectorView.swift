//
//  InspectorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/13/25.
//

import SwiftUI

struct InspectorView: View {

    @BindableEnvironment(\.projectManager) private var projectManager
    @BindableEnvironment(\.editorSession) private var editorSession

    @State private var selectedTab: InspectorTab = .attributes

    private var singleSelectedID: UUID? {
        guard editorSession.selectedNodeIDs.count == 1 else { return nil }
        return editorSession.selectedNodeIDs.first
    }

    private var activeGraph: CanvasGraph? {
        switch editorSession.selectedEditor {
        case .schematic:
            return editorSession.schematicController.graph
        case .layout:
            return editorSession.layoutController.graph
        }
    }

    private var selectedGraphID: NodeID? {
        guard let selectedID = singleSelectedID,
            let graph = activeGraph
        else { return nil }
        let nodeID = NodeID(selectedID)
        return graph.hasAnyComponent(for: nodeID) ? nodeID : nil
    }

    /// A computed property that finds the ComponentInstance for a selected schematic symbol.
    private var selectedSymbolComponent: ComponentInstance? {
        guard editorSession.selectedEditor == .schematic,
            let selectedID = singleSelectedID,
            let componentInstance = projectManager.componentInstances.first(where: {
                $0.id == selectedID
            })
        else { return nil }
        return componentInstance
    }

    /// A computed property that finds the ComponentInstance for a selected layout footprint.
    private var selectedFootprintContext:
        (component: ComponentInstance, footprint: Binding<CanvasFootprint>)?
    {
        guard editorSession.selectedEditor == .layout,
            let nodeID = selectedGraphID,
            let footprintBinding = editorSession.layoutController.footprintBinding(
                for: nodeID.rawValue),
            let componentInstance = projectManager.componentInstances.first(where: {
                $0.id == nodeID.rawValue
            })
        else { return nil }

        return (componentInstance, footprintBinding)
    }

    private var selectedTextBinding: Binding<CanvasText>? {
        guard let nodeID = selectedGraphID else { return nil }
        switch editorSession.selectedEditor {
        case .schematic:
            return editorSession.schematicController.textBinding(for: nodeID.rawValue)
        case .layout:
            return editorSession.layoutController.textBinding(for: nodeID.rawValue)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch editorSession.selectedEditor {

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
        if let component = selectedSymbolComponent {
            SymbolNodeInspectorHostView(
                component: component,
                selectedTab: $selectedTab
            )
            .id(component.id)

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

        } else if let selection = editorSession.layoutController.singleSelectedPrimitive,
            let binding = editorSession.layoutController.primitiveBinding(
                for: selection.id.rawValue)
        {
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
            Text(
                editorSession.selectedNodeIDs.isEmpty ? "No Selection" : "Multiple Items Selected"
            )
            .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
