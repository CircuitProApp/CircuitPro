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

    @FocusState private var focusedField: ComponentDetailsFocusField?
    
    var body: some View {
        NavigationSplitView {
            sidebarContent
              
        } content: {
            stageContent
        } detail: {
      
            detailContent
       
         
        }
    }
    
    @ViewBuilder
    private var sidebarContent: some View {
        VStack(spacing: 0) {
     
            VStack(spacing: 0) {
               
                    Button {
                        currentStage = .details
                    } label: {
                        Text("Component Details")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .directionalPadding(vertical: 4, horizontal: 6)
                            .background(currentStage == .details ? Color.blue : nil)
                            .contentShape(.rect)
                            .clipShape(.rect(cornerRadius: 5))
                    }
                    Button {
                        currentStage = .symbol
                    } label: {
                        Text("Symbol Editor")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .directionalPadding(vertical: 4, horizontal: 6)
                            .background(currentStage == .symbol ? Color.blue : nil)
                            .contentShape(.rect)
                            .clipShape(.rect(cornerRadius: 5))
                    }
                    Button {
                        currentStage = .footprint
                    } label: {
                        Text("Footprint Editor")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .directionalPadding(vertical: 4, horizontal: 6)
                            .background(currentStage == .footprint ? Color.blue : nil)
                            .contentShape(.rect)
                            .clipShape(.rect(cornerRadius: 5))
                    }
              
            }
            .buttonStyle(NoHighlightButtonStyle())
            .padding(10)
       


            Divider()
            VStack(spacing: 0) {
                switch currentStage {
                case .details:
                    
                    EmptyView()
                case .symbol:
                    SymbolElementListView()
                case .footprint:
                    FootprintElementListView()
                }
            }
            .frame(maxHeight: .infinity)
        }
        .navigationSplitViewColumnWidth(min: ComponentDesignConstants.sidebarWidth, ideal: ComponentDesignConstants.sidebarWidth, max: 350)
     
    }
    
    @ViewBuilder
    private var detailContent: some View {
        VStack {
            switch currentStage {
            case .details:
                switch focusedField {
                case .name:
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Component Name")
                            .font(.headline)
                        Text("Provide a descriptive name for the component. This name should clearly identify the component's function, for example, 'Light Emitting Diode' or 'Ceramic Capacitor'.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                case .referencePrefix:
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Reference Designator Prefix")
                            .font(.headline)
                        Text("Enter the reference designator prefix. This is a shorthand used to identify components on a schematic, such as 'LED' for a Light Emitting Diode or 'C' for a capacitor.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                case nil:
                    Text("No Selection")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
            case .symbol:
                selectionBasedDetailView(
                    count: componentDesignManager.symbolEditor.selectedElementIDs.count,
                    content: SymbolPropertiesView.init
                )
                .environment(componentDesignManager.symbolEditor)
            case .footprint:
                selectionBasedDetailView(
                    count: componentDesignManager.footprintEditor.selectedElementIDs.count,
                    content: FootprintPropertiesView.init
                )
                .environment(componentDesignManager.footprintEditor)
            }
        }
        .navigationSplitViewColumnWidth(min: ComponentDesignConstants.sidebarWidth, ideal: ComponentDesignConstants.sidebarWidth, max: 350)
    }
    
    @ViewBuilder
    private var stageContent: some View {
        switch currentStage {
        case .details:
           
            ComponentDetailsView(focusedField: $focusedField)
             
            .directionalPadding(vertical: 100, horizontal: 50)
            .navigationTitle("Component Details")
        case .symbol:
            SymbolCanvasView()
                .environment(symbolCanvasManager)
                .navigationTitle("Symbol Editor")
        case .footprint:
            FootprintCanvasView()
                .environment(footprintCanvasManager)
                .navigationTitle("Footprint Editor")
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
