//
//  ComponentDesignNavigator.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/13/25.
//

import SwiftUI

struct ComponentDesignNavigator: View {
    
    @Environment(ComponentDesignManager.self)
    private var componentDesignManager
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Stage Selection
            VStack(spacing: 0) {
                stageNavigationButton(stage: .details, label: "Component Details")
                stageNavigationButton(stage: .symbol, label: "Symbol Editor")
                stageNavigationButton(stage: .footprint, label: "Footprint Hub")
            }
            .buttonStyle(.plain)
            .padding(10)
            
            Divider()
            
            // MARK: - Contextual Element List
            VStack(spacing: 0) {
                switch componentDesignManager.currentStage {
                case .details:
                    EmptyView()
                    
                case .symbol:
                    SymbolElementListView()
                    
                case .footprint:
                    // CORRECTED: This now checks for the selected draft.
                    // The element list is only shown when editing a specific footprint.
                    if let draft = componentDesignManager.selectedFootprintDraft {
                        FootprintElementListView()
                            // Pass the editor from the selected draft into the environment.
                            .environment(draft.editor)
                    } else {
                        // When the user is viewing the Hub, this area is empty.
                        EmptyView()
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 220, max: 350)
    }
    
    private func stageNavigationButton(stage: ComponentDesignStage, label: String) -> some View {
        Button {
            // ADDED LOGIC: When switching to the Footprint stage, always reset
            // the selection. This ensures the user always sees the Hub first.
            if stage == .footprint {
                componentDesignManager.selectedFootprintID = nil
            }
            componentDesignManager.currentStage = stage
        } label: {
            Text(label)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                // Use the stage's ID for a reliable comparison.
                .background(componentDesignManager.currentStage.id == stage.id ? Color.blue : nil)
                .foregroundStyle(componentDesignManager.currentStage.id == stage.id ? .white : .primary)
                .contentShape(.rect)
                .clipShape(.rect(cornerRadius: 5))
        }
    }
}
