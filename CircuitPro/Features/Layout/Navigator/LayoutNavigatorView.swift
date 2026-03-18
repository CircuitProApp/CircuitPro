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

    var body: some View {
        VStack(spacing: 0) {
            SegmentedPicker(
                options: LayoutNavigatorTab.allCases,
                selection: $selectedTab
            ) { tab in
                tab.label
            }

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
