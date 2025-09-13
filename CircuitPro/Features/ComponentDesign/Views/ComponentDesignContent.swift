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
            if let draft = componentDesignManager.selectedFootprintDraft {
                FootprintCanvasView()
                    .environment(footprintCanvasManager)
                    .environment(draft.editor)
                    .id(draft.id)
                    .navigationTitle(draft.name)
                    .toolbar {
                        ToolbarItem(placement: .navigation) {
                            Button {
                                componentDesignManager.selectedFootprintID = nil
                            } label: {
                                Image(systemName: "chevron.left")
                                    .frame(width: 16, height: 16)
                             
                            }
                   
                        }
                    }
            } else {
                FootprintHubView()
                    .navigationTitle("Footprint Hub")
            }
        }
    }
}
