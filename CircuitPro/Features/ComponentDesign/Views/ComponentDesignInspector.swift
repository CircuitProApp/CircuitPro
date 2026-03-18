//
//  ComponentDesignInspector.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/13/25.
//

import SwiftUI

struct ComponentDesignInspector: View {

    @Environment(ComponentDesignManager.self)
    private var componentDesignManager

    var body: some View {
        VStack {
            switch componentDesignManager.currentStage {
            case .details:
                SidebarContentUnavailableView(
                    "No Selection",
                    description: "Select a field to see details."
                )

            case .symbol:
                selectionBasedDetailView(
                    count: componentDesignManager.symbolEditor.selectedElementIDs.count,
                    content: SymbolPropertiesView.init
                )
                .environment(componentDesignManager.symbolEditor)

            case .footprint:
                if let editor = componentDesignManager.selectedFootprintDraft?.editor {
                    selectionBasedDetailView(
                        count: editor.selectedElementIDs.count,
                        content: FootprintPropertiesView.init
                    )
                    .environment(editor)
                } else {
                    SidebarContentUnavailableView(
                        "No Selection",
                        description: "Select a footprint to see its properties."
                    )
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 220, max: 350)
    }

    @ViewBuilder
    private func selectionBasedDetailView<Content: View>(
        count: Int,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        switch count {
        case 0: SidebarContentUnavailableView("No Selection")
        case 1: content()
        default: SidebarContentUnavailableView("Multiple Items Selected")
        }
    }
}
