//
//  SchematicNavigatorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/14/25.
//

import SwiftUI

struct SchematicNavigatorView: View {

    enum SchematicNavigatorTab: Displayable {
        case symbols
        case nets
        
        var label: String {
            switch self {
            case .symbols:
                return "Symbols"
            case .nets:
                return "Nets"
            }
        }
    }

    @State private var selectedTab: SchematicNavigatorTab = .symbols
    
    @Namespace private var namespace

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 2.5) {
                ForEach(SchematicNavigatorTab.allCases, id: \.self) { tab in
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

            switch selectedTab {
            case .symbols:
                SymbolNavigatorView()
                    .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .leading)))
       
            case .nets:
                NetNavigatorView()
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
            }
        }
    }
}
