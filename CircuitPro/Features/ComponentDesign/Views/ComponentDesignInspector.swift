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
    
    var currentStage: ComponentDesignStage {
        componentDesignManager.currentStage
    }
    
    var body: some View {
        VStack {
            switch currentStage {
            case .details: Text("Select a field to see details.").font(.callout).foregroundColor(.secondary)
            case .symbol: selectionBasedDetailView(count: componentDesignManager.symbolEditor.selectedElementIDs.count, content: SymbolPropertiesView.init).environment(componentDesignManager.symbolEditor)
            case .footprint:
                // MODIFIED: Use the restored selectedFootprintEditor
                if let editor = componentDesignManager.selectedFootprintEditor {
                    selectionBasedDetailView(count: editor.selectedElementIDs.count, content: FootprintPropertiesView.init).environment(editor)
                } else {
                    Text("Select a footprint to see its properties.").font(.callout).foregroundColor(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
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
        case 0: Text("No Selection").font(.callout).foregroundColor(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
        case 1: content()
        default: Text("Multiple Items Selected").font(.callout).foregroundColor(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
