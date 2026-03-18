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
            HStack(spacing: 4) {
                ForEach(LayoutNavigatorTab.allCases, id: \.self) { tab in
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

            // --- MODIFIED: Switch now uses the new, dedicated views ---
            switch selectedTab {
            case .footprints:
                FootprintNavigatorView()
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .leading), removal: .move(edge: .leading)))

            case .layers:
                LayerNavigatorListView()
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
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
