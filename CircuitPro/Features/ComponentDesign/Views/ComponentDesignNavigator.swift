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
                    if let draft = componentDesignManager.selectedFootprintDraft {
                        FootprintElementListView()
                            .environment(draft.editor)
                    } else {
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
            if stage == .footprint {
                componentDesignManager.selectedFootprintID = nil
            }
            componentDesignManager.currentStage = stage
        } label: {
            Text(label)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .background(componentDesignManager.currentStage.id == stage.id ? Color.blue : nil)
                .foregroundStyle(componentDesignManager.currentStage.id == stage.id ? .white : .primary)
                .contentShape(.rect)
                .clipShape(.rect(cornerRadius: 5))
        }
    }
}
