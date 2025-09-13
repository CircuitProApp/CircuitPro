//
//  ComponentDesignContent.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/13/25.
//

import SwiftUI

struct ComponentDesignContent: View {
    
    @Environment(ComponentDesignManager.self)
    private var componentDesignManager
    
    var symbolCanvasManager: CanvasManager
    var footprintCanvasManager: CanvasManager
    
    @FocusState private var focusedField: ComponentDetailsFocusField?
    
    var body: some View {
        @Bindable var componentDesignManager = componentDesignManager

        switch componentDesignManager.currentStage {
        case .details:
            ComponentDetailsView(focusedField: $focusedField)
                .navigationTitle("Component Details")
                
        case .symbol:
            SymbolCanvasView()
                .environment(symbolCanvasManager)
                .navigationTitle("Symbol Editor")
                
        case .footprint:
            // --- MANUAL NAVIGATION LOGIC ---
            // If a draft is selected, show the canvas editor.
            if let draft = componentDesignManager.selectedFootprintDraft {
                FootprintCanvasView()
                    .environment(footprintCanvasManager)
                    .environment(draft.editor)
                    .id(draft.id)
                    .navigationTitle(draft.name)
                    // ADDED: A toolbar with a back button that only appears with the canvas.
                    .toolbar {
                        ToolbarItem(placement: .navigation) {
                            Button {
                                // The action to "navigate back" is to deselect the current draft.
                                componentDesignManager.selectedFootprintID = nil
                            } label: {
                                
                                Image(systemName: "chevron.left")
                                    .frame(width: 16, height: 16)
                             
                            }
                   
                        }
                    }
            } else {
                // If NO draft is selected, show the Hub.
                FootprintHubView()
                    .navigationTitle("Footprint Hub")
            }
        }
    }
}
