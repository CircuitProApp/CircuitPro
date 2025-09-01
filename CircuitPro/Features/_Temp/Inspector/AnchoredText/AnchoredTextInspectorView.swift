//
//  AnchoredTextInspectorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/28/25.
//

import SwiftUI

struct AnchoredTextInspectorView: View {
    
    @Bindable var anchoredText: AnchoredTextNode
    
    @State private var selectedTab: InspectorTab = .attributes
    
    var availableTabs: [InspectorTab] = [.attributes]
    
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
                            point: $anchoredText.anchorPosition
                        )
                        PointControlView(
                            title: "Position",
                            point: $anchoredText.resolvedText.relativePosition
                        )
                        
//                        RotationControlView(object: $anchoredText.textModel)
                        
                    }
                    Divider()
                    InspectorSection("Text Options") {
                        InspectorAnchorRow(textAnchor: $anchoredText.resolvedText.anchor)
                    }
                }
                .padding(5)
            }
        }
    }
}
