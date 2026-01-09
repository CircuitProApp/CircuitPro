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
        guard editorSession.selectedItemIDs.count == 1 else { return nil }
        return editorSession.selectedItemIDs.first
    }

    private var selectedSchematicID: UUID? {
        guard editorSession.selectedEditor == .schematic else { return nil }
        return singleSelectedID
    }

    private var selectedLayoutID: UUID? {
        guard editorSession.selectedEditor == .layout else { return nil }
        return singleSelectedID
    }

    private var selectedSchematicTextBinding: Binding<CircuitText.Resolved>? {
        guard editorSession.selectedEditor == .schematic,
              let selectedID = selectedSchematicID
        else { return nil }
        return componentTextBinding(
            for: selectedID,
            target: .symbol
        )
    }

    private var selectedLayoutTextBinding: Binding<CircuitText.Resolved>? {
        guard editorSession.selectedEditor == .layout,
              let selectedID = selectedLayoutID
        else { return nil }
        return componentTextBinding(
            for: selectedID,
            target: .footprint
        )
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
        if let textBinding = selectedSchematicTextBinding {
            ResolvedTextInspectorView(text: textBinding)
        } else if let component = selectedSymbolComponent {
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
        if let textBinding = selectedLayoutTextBinding {
            ResolvedTextInspectorView(text: textBinding)
        } else if let context = selectedFootprintContext {
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
                editorSession.selectedItemIDs.isEmpty ? "No Selection" : "Multiple Items Selected"
            )
            .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func componentTextBinding(
        for selectedID: UUID,
        target: TextTarget
    ) -> Binding<CircuitText.Resolved>? {
        for component in projectManager.componentInstances {
            let resolvedItems: [CircuitText.Resolved]
            switch target {
            case .symbol:
                resolvedItems = component.symbolInstance.resolvedItems
            case .footprint:
                resolvedItems = component.footprintInstance?.resolvedItems ?? []
            }

            for resolved in resolvedItems {
                let textID = CanvasTextID.makeID(
                    for: resolved.source,
                    ownerID: component.id,
                    fallback: resolved.id
                )
                guard textID == selectedID else { continue }

                return Binding(
                    get: {
                        let currentItems: [CircuitText.Resolved]
                        switch target {
                        case .symbol:
                            currentItems = component.symbolInstance.resolvedItems
                        case .footprint:
                            currentItems = component.footprintInstance?.resolvedItems ?? []
                        }
                        return currentItems.first(where: { item in
                            CanvasTextID.makeID(
                                for: item.source,
                                ownerID: component.id,
                                fallback: item.id
                            ) == selectedID
                        }) ?? resolved
                    },
                    set: { updated in
                        component.apply(updated, for: target)
                    }
                )
            }
        }
        return nil
    }
}
