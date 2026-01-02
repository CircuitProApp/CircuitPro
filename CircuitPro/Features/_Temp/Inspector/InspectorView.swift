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

    private var selectedSchematicID: UUID? {
        guard editorSession.selectedEditor == .schematic else { return nil }
        return singleSelectedID
    }

    private var selectedLayoutNodeID: NodeID? {
        guard editorSession.selectedEditor == .layout,
            let selectedID = singleSelectedID
        else { return nil }
        let nodeID = NodeID(selectedID)
        return editorSession.layoutController.graph.hasAnyComponent(for: nodeID) ? nodeID : nil
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
            let nodeID = selectedLayoutNodeID,
            let footprintBinding = editorSession.layoutController.footprintBinding(
                for: nodeID.rawValue),
            let componentInstance = projectManager.componentInstances.first(where: {
                $0.id == nodeID.rawValue
            })
        else { return nil }

        return (componentInstance, footprintBinding)
    }

    private var selectedTextBinding: Binding<CanvasText>? {
        switch editorSession.selectedEditor {
        case .schematic:
            guard let id = selectedSchematicID else { return nil }
            return editorSession.schematicController.textBinding(for: id)
        case .layout:
            guard let nodeID = selectedLayoutNodeID else { return nil }
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
