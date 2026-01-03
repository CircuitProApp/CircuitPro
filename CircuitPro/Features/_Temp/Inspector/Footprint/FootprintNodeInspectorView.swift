//
//  FootprintNodeInspectorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/19/25.
//

//
//  FootprintNodeInspectorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 09.15.25.
//

import SwiftUI

struct FootprintNodeInspectorView: View {

    @Environment(\.projectManager)
    private var projectManager

    /// The component instance that this footprint belongs to.
    /// This is used for displaying contextual information, like the RefDes.
    var component: ComponentInstance

    /// The graph-backed footprint component being inspected.
    @Binding var footprint: FootprintInstance

    @State private var selectedTab: InspectorTab = .attributes
    private var availableTabs: [InspectorTab] = [.attributes]

    @State private var commitSessionID: UUID?  // NEW

    private func withCommitSession(_ perform: (UUID) -> Void) {
        let id: UUID
        if let s = commitSessionID {
            id = s
        } else {
            id = projectManager.syncManager.beginSession()
            commitSessionID = id
            // End the session after the current commit burst settles.
            DispatchQueue.main.async { [weak projectManager] in
                projectManager?.syncManager.endSession(id)
                commitSessionID = nil
            }
        }
        perform(id)
    }

    /// A custom binding to safely get and set the board side from the `PlacementState` enum.
    private var placementSideBinding: Binding<BoardSide> {
        Binding(
            get: {
                // If the footprint is placed, return its side.
                // Otherwise, default to .front for the picker's initial state.
                if case .placed(let side) = component.footprintInstance?.placement {
                    return side
                }
                return .front
            },
            set: { newSide in
                // When the picker's value changes, update the instance's placement.
                component.footprintInstance?.placement = .placed(side: newSide)
            }
        )
    }

    private var refdesIndexBinding: Binding<Int> {
        Binding(
            get: {
                projectManager.syncManager.resolvedReferenceDesignator(
                    for: component, onlyFrom: .layout)
            },
            set: { newIndex in
                let current = projectManager.syncManager.resolvedReferenceDesignator(
                    for: component, onlyFrom: .layout)
                guard newIndex != current else { return }
                withCommitSession { session in
                    projectManager.updateReferenceDesignator(
                        for: component,
                        newIndex: newIndex,
                        source: .layout,
                        sessionID: session
                    )
                }
            }
        )
    }

    private var positionBinding: Binding<CGPoint> {
        Binding(
            get: { footprint.position },
            set: { newValue in
                var updated = footprint
                updated.position = newValue
                footprint = updated
            }
        )
    }

    init(component: ComponentInstance, footprint: Binding<FootprintInstance>) {
        self.component = component
        self._footprint = footprint
    }

    var body: some View {
        SidebarView(selectedTab: $selectedTab, availableTabs: availableTabs) {
            ScrollView {
                VStack(alignment: .leading, spacing: 5) {
                    InspectorSection("Identity") {
                        InspectorRow("Name") {
                            Text(component.definition?.name ?? "n/a")
                                .foregroundStyle(.secondary)
                        }
                        InspectorRow("Refdes", style: .leading) {
                            InspectorNumericField(
                                label: component.definition?.referenceDesignatorPrefix,
                                value: refdesIndexBinding,  // This now gets the resolved value
                                placeholder: "?",
                                labelStyle: .prominent
                            )
                        }
                    }

                    Divider()

                    InspectorSection("Placement") {
                        InspectorRow("Side") {
                            Picker("Side", selection: placementSideBinding) {
                                Text("Front").tag(BoardSide.front)
                                Text("Back").tag(BoardSide.back)
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                        }
                    }

                    Divider()

                    // Manual implementation of the Transform section.
                    InspectorSection("Transform") {
                        PointControlView(
                            title: "Position",
                            point: positionBinding
                        )
                        RotationControlView(object: $footprint)
                    }
                }
                .padding(5)
            }
        }
    }
}
