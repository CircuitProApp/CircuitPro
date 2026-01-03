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

    private var selectedLayoutID: UUID? {
        guard editorSession.selectedEditor == .layout else { return nil }
        return singleSelectedID
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
        (component: ComponentInstance, footprint: Binding<FootprintInstance>)?
    {
        guard editorSession.selectedEditor == .layout,
            let selectedID = selectedLayoutID,
            let componentInstance = projectManager.componentInstances.first(where: {
                $0.id == selectedID
            }),
            let footprintInstance = componentInstance.footprintInstance
        else { return nil }

        let footprintBinding = Binding(
            get: { componentInstance.footprintInstance ?? footprintInstance },
            set: { componentInstance.footprintInstance = $0 }
        )
        return (componentInstance, footprintBinding)
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
