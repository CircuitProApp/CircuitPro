//
//  LayoutNavigatorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/14/25.
//

import SwiftUI

struct LayoutNavigatorView: View {

    // --- MODIFIED: Renamed tabs to be more accurate ---
    enum LayoutNavigatorTab: String, Displayable {
        case footprints
        case layers
        
        var label: String {
            return self.rawValue.capitalized
        }
    }

    @State private var selectedTab: LayoutNavigatorTab = .footprints
    @Namespace private var namespace

    var body: some View {
        VStack(spacing: 0) {
            // Tab selection bar (unchanged)
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

            // --- MODIFIED: Switch now uses the new, dedicated views ---
            switch selectedTab {
            case .footprints:
                FootprintNavigatorView()
                    .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .leading)))
       
            case .layers:
                LayerNavigatorListView()
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
            }
        }
    }
}

// Helpers can be kept here for now or moved to their model files
extension LayerSide {
    static let none: LayerSide = .inner(0)
    var headerTitle: String {
        switch self {
        case .front: return "Front Layers"
        case .back: return "Back Layers"
        case .inner(let index): return index == 0 ? "General" : "Inner Layers"
        }
    }
}

extension ComponentInstance {
    var referenceDesignator: String {
        let prefix = self.definition?.referenceDesignatorPrefix ?? "REF?"
        return prefix + String(self.referenceDesignatorIndex)
    }
}
