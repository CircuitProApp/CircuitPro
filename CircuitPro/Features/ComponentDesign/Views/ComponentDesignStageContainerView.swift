//
//  ComponentDesignStageContainerView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 18.06.25.
//

import SwiftUI

struct ComponentDesignStageContainerView: View {
    
    @Binding var currentStage: ComponentDesignStage
    
    @Environment(\.componentDesignManager)
    private var componentDesignManager
    
    let symbolCanvasManager: CanvasManager
    let footprintCanvasManager: CanvasManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            NavigationSplitView {
                VStack {
                    switch currentStage {
                    case .details:
                        EmptyView()
                            .toolbar(removing: .sidebarToggle)
                    case .symbol:
                        SymbolElementListView()
                    case .footprint:
                        FootprintElementListView()
                    }
                }
                .navigationSplitViewColumnWidth(currentStage == .details ? 0 : ComponentDesignConstants.sidebarWidth)
            } content: {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        if currentStage == .details {
                            Spacer()
                                .frame(width: ComponentDesignConstants.sidebarWidth)
                        }
                      
                        StageIndicatorView(
                            currentStage: $currentStage,
                            validationProvider: componentDesignManager.validationState
                        )
                        Spacer()
                    }
                   
                    Divider()
                    switch currentStage {
                    case .details:
    
                            HStack {
                                Spacer()
                                    .frame(width: ComponentDesignConstants.sidebarWidth)
                                ComponentDetailView()
                                Spacer()
                                    .frame(width: ComponentDesignConstants.sidebarWidth)
                            }
                            .padding(.vertical, 25)
                     
                    case .symbol:
                        SymbolDesignView()
                            .environment(symbolCanvasManager)
                    case .footprint:
                        FootprintDesignView()
                            .environment(footprintCanvasManager)
                    }
                }
                
            } detail: {
                VStack {
                switch currentStage {
                case .details:
                    EmptyView()
                case .symbol:
                    SymbolPropertiesEditorView()
                case .footprint:
                    FootprintPropertiesEditorView()
                }
                }
                .navigationSplitViewColumnWidth(currentStage == .details ? 0 : ComponentDesignConstants.sidebarWidth)
       
            }
            .navigationTransition(.automatic)
        }
    }
}
