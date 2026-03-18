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

    var body: some View {
        VStack(spacing: 0) {
            SegmentedPicker(
                options: SchematicNavigatorTab.allCases,
                selection: $selectedTab
            ) { tab in
                tab.label
            }

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
