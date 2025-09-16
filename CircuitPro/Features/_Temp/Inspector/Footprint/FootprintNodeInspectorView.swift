//
//  FootprintNodeInspectorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 09.15.25.
//

import SwiftUI

struct FootprintNodeInspectorView: View {
    
    /// The component instance that this footprint belongs to.
    /// This is used for displaying contextual information, like the RefDes.
    var component: ComponentInstance
    
    /// The actual scene node being inspected. Use @Bindable to allow direct editing of its properties.
    @Bindable var footprintNode: FootprintNode
    
    @State private var selectedTab: InspectorTab = .attributes
    private var availableTabs: [InspectorTab] = [.attributes]
    
    /// A custom binding to safely get and set the board side from the `PlacementState` enum.
    private var placementSideBinding: Binding<BoardSide> {
        Binding(
            get: {
                // If the footprint is placed, return its side.
                // Otherwise, default to .front for the picker's initial state.
                if case .placed(let side) = footprintNode.instance.placement {
                    return side
                }
                return .front
            },
            set: { newSide in
                // When the picker's value changes, update the instance's placement.
                footprintNode.instance.placement = .placed(side: newSide)
            }
        )
    }
    
    init(component: ComponentInstance, footprintNode: FootprintNode) {
        self.component = component
        self.footprintNode = footprintNode
    }

    var body: some View {
        SidebarView(selectedTab: $selectedTab, availableTabs: availableTabs) {
            ScrollView {
                VStack(alignment: .leading, spacing: 5) {
                    InspectorSection("Identity") {
                        InspectorRow("Refdes") {
                            // Display the reference designator from the parent component.
                            Text(component.referenceDesignator)
                                .foregroundStyle(.secondary)
                        }
                        InspectorRow("Footprint") {
                            // Display the name of the footprint definition.
                            Text(footprintNode.instance.definition?.name ?? "n/a")
                                .foregroundStyle(.secondary)
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
                            point: $footprintNode.instance.position
                        )
                        RotationControlView(object: $footprintNode.instance)
                    }
                }
                .padding(5)
            }
        }
    }
}
