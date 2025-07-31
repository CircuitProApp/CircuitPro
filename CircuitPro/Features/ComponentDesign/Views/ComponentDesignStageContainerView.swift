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
        
        NavigationSplitView {
            VStack {
                sidebarContent
            }
            .navigationSplitViewColumnWidth(currentStage == .details ? 0 : ComponentDesignConstants.sidebarWidth)
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                stageIndicator
                Divider()
                VStack(spacing: 0) {
                    stageContent
                }
            }
        } detail: {
            VStack {
                detailContent
            }
            .navigationSplitViewColumnWidth(currentStage == .details ? 0 : ComponentDesignConstants.sidebarWidth)
            
        }
        
    }
    
    var stageIndicator: some View {
        HStack {
            StageIndicatorView(
                currentStage: $currentStage,
                validationProvider: componentDesignManager.validationState
            )
            .if(currentStage == .details) {
                $0.offset(.init(width: ComponentDesignConstants.sidebarWidth, height: 0))
            }
           
            
            Spacer()
            
        }
        .background(.windowBackground)
    }
    
    @ViewBuilder
    var sidebarContent: some View {
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
    
    @ViewBuilder
    var detailContent: some View {
        switch currentStage {
        case .details:
            EmptyView()
        case .symbol:
            SymbolPropertiesEditorView()
        case .footprint:
            FootprintPropertiesEditorView()
        }
    }
    
    @ViewBuilder
    var stageContent: some View {
        switch currentStage {
        case .details:
            HStack {
                Spacer()
                    .frame(width: ComponentDesignConstants.sidebarWidth)
                ComponentDetailView()
                Spacer()
                    .frame(width: ComponentDesignConstants.sidebarWidth)
            }
            .directionalPadding(vertical: 25, horizontal: 15)
        case .symbol:
            SymbolDesignView()
                .environment(symbolCanvasManager)
        case .footprint:
            FootprintDesignView()
                .environment(footprintCanvasManager)
        }
    }
}
