//
//  AnchoredTextInspectorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/28/25.
//

import SwiftUI

struct GraphTextInspectorView: View {

    @Binding var text: CircuitText.Definition

    @State private var selectedTab: InspectorTab = .attributes

    var availableTabs: [InspectorTab] = [.attributes]

    private var anchorPositionBinding: Binding<CGPoint> {
        Binding(
            get: { text.anchorPosition },
            set: { newValue in
                var updated = text
                updated.anchorPosition = newValue
                text = updated
            }
        )
    }

    private var positionBinding: Binding<CGPoint> {
        Binding(
            get: { text.relativePosition },
            set: { newValue in
                var updated = text
                updated.relativePosition = newValue
                text = updated
            }
        )
    }

    private var anchorBinding: Binding<TextAnchor> {
        Binding(
            get: { text.anchor },
            set: { newValue in
                var updated = text
                updated.anchor = newValue
                text = updated
            }
        )
    }

    var body: some View {
        SidebarView(selectedTab: $selectedTab, availableTabs: availableTabs) {
            ScrollView {
                VStack(spacing: 5) {
                    //                    InspectorSection("Identity and Type") {
                    //                        InspectorRow("Visibility") {
                    //
                    //                        }
                    //
                    //                    }
                    InspectorSection("Transform") {
                        PointControlView(
                            title: "Anchor",
                            point: anchorPositionBinding
                        )
                        PointControlView(
                            title: "Position",
                            point: positionBinding
                        )

                        //                        RotationControlView(object: $anchoredText)

                    }
                    Divider()
                    InspectorSection("Text Options") {
                        InspectorAnchorRow(textAnchor: anchorBinding)
                    }
                }
                .padding(5)
            }
        }
    }
}

struct ResolvedTextInspectorView: View {

    @Binding var text: CircuitText.Resolved

    @State private var selectedTab: InspectorTab = .attributes

    var availableTabs: [InspectorTab] = [.attributes]

    private var anchorPositionBinding: Binding<CGPoint> {
        Binding(
            get: { text.anchorPosition },
            set: { newValue in
                var updated = text
                updated.anchorPosition = newValue
                text = updated
            }
        )
    }

    private var positionBinding: Binding<CGPoint> {
        Binding(
            get: { text.relativePosition },
            set: { newValue in
                var updated = text
                updated.relativePosition = newValue
                text = updated
            }
        )
    }

    private var anchorBinding: Binding<TextAnchor> {
        Binding(
            get: { text.anchor },
            set: { newValue in
                var updated = text
                updated.anchor = newValue
                text = updated
            }
        )
    }

    var body: some View {
        SidebarView(selectedTab: $selectedTab, availableTabs: availableTabs) {
            ScrollView {
                VStack(spacing: 5) {
                    InspectorSection("Transform") {
                        PointControlView(
                            title: "Anchor",
                            point: anchorPositionBinding
                        )
                        PointControlView(
                            title: "Position",
                            point: positionBinding
                        )
                    }
                    Divider()
                    InspectorSection("Text Options") {
                        InspectorAnchorRow(textAnchor: anchorBinding)
                    }
                }
                .padding(5)
            }
        }
    }
}
