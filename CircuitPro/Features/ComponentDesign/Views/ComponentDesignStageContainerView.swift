//
//  ComponentDesignStageContainerView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 18.06.25.
//

import SwiftUI

struct ComponentDesignStageContainerView: View {
    
    @Binding var currentStage: ComponentDesignStage
    
    @Environment(ComponentDesignManager.self)
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
    
    // MARK: - Subviews
    
    private var stageIndicator: some View {
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
    private var sidebarContent: some View {
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
    private var detailContent: some View {
        switch currentStage {
        case .details:
            EmptyView()

        case .symbol:
            selectionBasedDetailView(
                count: componentDesignManager.symbolEditor.selectedElementIDs.count,
                content: SymbolPropertiesView.init
            )

        case .footprint:
            selectionBasedDetailView(
                count: componentDesignManager.footprintEditor.selectedElementIDs.count,
                content: FootprintPropertiesView.init
            )
        }
    }
    
    @ViewBuilder
    private var stageContent: some View {
        switch currentStage {
        case .details:
            HStack {
                Spacer()
                    .frame(width: ComponentDesignConstants.sidebarWidth)
                ComponentDetailsView()
                Spacer()
                    .frame(width: ComponentDesignConstants.sidebarWidth)
            }
            .directionalPadding(vertical: 25, horizontal: 15)
        case .symbol:
            SymbolCanvasView()
                .environment(symbolCanvasManager)
        case .footprint:
            FootprintCanvasView()
                .environment(footprintCanvasManager)
        }
    }

    @ViewBuilder
    private func selectionBasedDetailView<Content: View>(
        count: Int,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        switch count {
        case 0:
            Text("No Selection")
                .font(.callout)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case 1:
            content()
        default:
            Text("Multiple Items Selected")
                .font(.callout)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
