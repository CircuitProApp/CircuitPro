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
            HStack(spacing: 4) {
                ForEach(SchematicNavigatorTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.smooth(duration: 0.3)) {
                            selectedTab = tab
                        }
                    } label: {
                        Text(tab.label)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(selectedTab == tab ? .white : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background {
                                if selectedTab == tab {
                                    Capsule()
                                        .fill(.blue)
                                        .matchedGeometryEffect(
                                            id: "selection-background", in: namespace)
                                }
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(
                Capsule()
                    .fill(.quaternary.opacity(0.6))
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            switch selectedTab {
            case .symbols:
                SymbolNavigatorView()
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .leading), removal: .move(edge: .leading)))

            case .nets:
                NetNavigatorView()
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
            }
        }
    }
}
