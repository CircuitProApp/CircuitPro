//
//  LayoutNavigatorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/14/25.
//

import SwiftUI

struct LayoutNavigatorView: View {

    var document: CircuitProjectFileDocument

    enum LayoutNavigatorTab: Displayable {
        case unplaced
        case layers
        
        var label: String {
            switch self {
            case .unplaced:
                return "Unplaced"
            case .layers:
                return "layers"
            }
        }
    }

    @State private var selectedTab: LayoutNavigatorTab = .unplaced
    
    @Namespace private var namespace

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 2.5) {
                ForEach(LayoutNavigatorTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.smooth(duration: 0.3)) {
                            selectedTab = tab
                        }
                    } label: {
                        Text(tab.label)
                            .padding(.vertical, 2.5)
                            .padding(.horizontal, 7.5)
                            .background {
                                if selectedTab == tab {
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(.blue)
                                        .matchedGeometryEffect(id: "selection-background", in: namespace)
                                }
                            }
                            .foregroundStyle(selectedTab == tab ? .white : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 28)
            .font(.callout)

            Divider().foregroundStyle(.quinary)

            switch selectedTab {
            case .unplaced:
                Text("PUnplaced")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .leading)))
       
            case .layers:
                Text("Layers")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
            }
        }
    }
}
