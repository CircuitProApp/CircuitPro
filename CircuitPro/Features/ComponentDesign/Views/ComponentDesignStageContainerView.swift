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
                    case .component:
                        EmptyView()
                            .toolbar(removing: .sidebarToggle)
                    case .symbol:
                        SymbolElementListView()
                    case .footprint:
                        FootprintElementListView()
                    }
                }
                .navigationSplitViewColumnWidth(currentStage == .component ? 0 : 200)
            } content: {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        if currentStage == .component {
                            Spacer()
                                .frame(width: 200)
                        }
                      
                        StageIndicatorView(
                            currentStage: $currentStage,
                            validationProvider: componentDesignManager.validationState
                        )
                        Spacer()
                    }
                    .background(.white)
                    Divider()
                    switch currentStage {
                    case .component:
    
                            HStack {
                                Spacer()
                                    .frame(width: 200)
                                ComponentDetailView()
                                Spacer()
                                    .frame(width: 200)
                            }
                            .padding(.vertical, 15)
                     
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
                case .component:
                    EmptyView()
                case .symbol:
                    SymbolPropertiesEditorView()
                case .footprint:
                    FootprintPropertiesEditorView()
                }
                }
                .navigationSplitViewColumnWidth(currentStage == .component ? 0 : 200)
       
            }
            .navigationTransition(.automatic)
        }
    }
}
