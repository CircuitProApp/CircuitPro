//
//  AnchoredTextInspectorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/28/25.
//

import SwiftUI

struct GraphTextInspectorView: View {

    @Binding var text: GraphTextComponent

    @State private var selectedTab: InspectorTab = .attributes

    var availableTabs: [InspectorTab] = [.attributes]

    private var anchorPositionBinding: Binding<CGPoint> {
        Binding(
            get: { text.resolvedText.anchorPosition },
            set: { newValue in
                var updated = text
                updated.resolvedText.anchorPosition = newValue
                text = updated
            }
        )
    }

    private var positionBinding: Binding<CGPoint> {
        Binding(
            get: { text.resolvedText.relativePosition },
            set: { newValue in
                var updated = text
                updated.resolvedText.relativePosition = newValue
                text = updated
            }
        )
    }

    private var anchorBinding: Binding<TextAnchor> {
        Binding(
            get: { text.resolvedText.anchor },
            set: { newValue in
                var updated = text
                updated.resolvedText.anchor = newValue
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
