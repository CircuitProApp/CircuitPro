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
    
    var currentStage: ComponentDesignStage {
        componentDesignManager.currentStage
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                stageNavigationButton(stage: .details, label: "Component Details")
                stageNavigationButton(stage: .symbol, label: "Symbol Editor")
                stageNavigationButton(stage: .footprint, label: "Footprint Hub")
            }
            .buttonStyle(.plain)
            .padding(10)
            
            Divider()
            
            VStack(spacing: 0) {
                switch currentStage {
                case .details: EmptyView()
                case .symbol: SymbolElementListView().environment(componentDesignManager.symbolEditor)
                case .footprint:
                    // MODIFIED: Use the restored selectedFootprintEditor
                    if let editor = componentDesignManager.selectedFootprintEditor {
                        FootprintElementListView().environment(editor)
                    } else {
                        Spacer()
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 220, max: 350)
    }
    
    private func stageNavigationButton(stage: ComponentDesignStage, label: String) -> some View {
        Button {
            componentDesignManager.currentStage = stage
        } label: {
            Text(label)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .background(currentStage == stage ? Color.blue : nil)
                .foregroundStyle(currentStage == stage ? .white : .primary)
                .contentShape(.rect)
                .clipShape(.rect(cornerRadius: 5))
        }
    }
}
