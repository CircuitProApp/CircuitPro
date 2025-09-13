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
    
    var currentStage: ComponentDesignStage {
        componentDesignManager.currentStage
    }
    
    var symbolCanvasManager: CanvasManager
    
    var footprintCanvasManager: CanvasManager
    
    @FocusState private var focusedField: ComponentDetailsFocusField?
    
    var body: some View {
        @Bindable var componentDesignManager = componentDesignManager

        switch currentStage {
        case .details:
            ComponentDetailsView(focusedField: $focusedField)
                .navigationTitle("Component Details")
                
        case .symbol:
            SymbolCanvasView()
                .environment(symbolCanvasManager)
                .environment(componentDesignManager.symbolEditor)
                .navigationTitle("Symbol Editor")
                
        case .footprint:
            NavigationStack(path: $componentDesignManager.navigationPath) {
                FootprintHubView()
                    .environment(footprintCanvasManager)
                    .navigationTitle("Footprint Hub")
                    .navigationDestination(for: FootprintDefinition.self) { footprint in
                        if let editor = componentDesignManager.footprintEditors[footprint.uuid] {
                            FootprintCanvasView()
                                .environment(footprintCanvasManager)
                                .environment(editor)
                                .navigationTitle(footprint.name)
                                // --- MODIFIED: This is the key fix ---
                                .onAppear {
                                    componentDesignManager.selectedFootprintID = footprint.uuid
                                }
                                .onDisappear {
                                    componentDesignManager.selectedFootprintID = nil
                                }
                        } else {
                            Text("Error: Editor not found for this footprint.")
                        }
                    }
            }
        }
    }
}
