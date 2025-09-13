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
//                    if !footprintNavigationPath.isEmpty, let editor = componentDesignManager.selectedFootprintEditor {
//                        FootprintElementListView().environment(editor)
//                    } else {
                        Spacer()
//                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 220, max: 350)
    }
    
    @ViewBuilder
    private var detailContent: some View {
        // ... This view is correct and does not need changes.
        VStack {
            switch currentStage {
            case .details: Text("Select a field to see details.").font(.callout).foregroundColor(.secondary)
            case .symbol: selectionBasedDetailView(count: componentDesignManager.symbolEditor.selectedElementIDs.count, content: SymbolPropertiesView.init).environment(componentDesignManager.symbolEditor)
            case .footprint:
//                if !footprintNavigationPath.isEmpty, let editor = componentDesignManager.selectedFootprintEditor {
//                    selectionBasedDetailView(count: editor.selectedElementIDs.count, content: FootprintPropertiesView.init).environment(editor)
//                } else {
                    Text("Select a footprint to see its properties.").font(.callout).foregroundColor(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
//                }
            }
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 220, max: 350)
    }
    
    @ViewBuilder
    private var stageContent: some View {
        
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
                                .onAppear {
                                    // This side-effect is now safe.
                                    componentDesignManager.selectedFootprintID = footprint.uuid
                                    print(componentDesignManager.selectedFootprintID)
                                }
                        } else {
                            Text("Error: Editor not found for this footprint.")
                        }
                    }
            }
        }
    }
    
    @ViewBuilder
    private func selectionBasedDetailView<Content: View>(
        count: Int,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        switch count {
        case 0: Text("No Selection").font(.callout).foregroundColor(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
        case 1: content()
        default: Text("Multiple Items Selected").font(.callout).foregroundColor(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func stageNavigationButton(stage: ComponentDesignStage, label: String) -> some View {
        Button {
            currentStage = stage
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
