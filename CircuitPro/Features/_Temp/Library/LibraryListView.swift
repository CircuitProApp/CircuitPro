//
//  LibraryListView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/11/25.
//

import SwiftUI

struct LibraryListView: View {
    
    
    @Environment(\.modelContext) private var modelContext
    
    var filteredComponents: [Component] = []
    @Binding var selectedComponentID: UUID?
    
    init(filteredComponents: [Component], selectedComponentID: Binding<UUID?>) {
        self.filteredComponents = filteredComponents
        self._selectedComponentID = selectedComponentID
        
        
    }
    
    
    
    var body: some View {
        if filteredComponents.isNotEmpty {
            ScrollView {
                LazyVStack(alignment: .leading, pinnedViews: .sectionHeaders) {
                    ForEach(ComponentCategory.allCases) { category in
                        // Filter the components for the current category.
                        let componentsInCategory = filteredComponents.filter { $0.category == category }
                        
                        if !componentsInCategory.isEmpty {
                            Section {
                                ForEach(componentsInCategory) { component in
                                    ComponentListRowView(component: component, category: category, selectedComponentID: $selectedComponentID)
                                        .padding(.horizontal, 6)
                                        .contentShape(.rect)
                                        #if DEBUG
                                        .contextMenu {
                                            Button("Delete") {
                                                modelContext.delete(component)
                                            }
                                        }
                                        #endif
                                    
                                    
                                    
                                }
                            } header: {
                                
                                Text(category.label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(2.5)
                                    .background(.ultraThinMaterial)
                                
                                
                                
                                
                            }
                            
                            
                            
                            
                        }
                    }
                }
                .frame(width: 272)
                
                
                
                
            }
            
        } else {
            Text("No Matches")
                .foregroundStyle(.secondary)
                .frame(width: 272)
                .frame(maxHeight: .infinity)
        }
        
    }
}


struct ComponentListRowView: View {
    
    var component: Component
    var category: ComponentCategory
    @Binding var selectedComponentID: UUID?
    
    private var isSelected: Bool {
        selectedComponentID == component.uuid
    }
    
    var body: some View {
        HStack {
            Text(component.referenceDesignatorPrefix)
            
                .frame(width: 32, height: 32)
                .background(category.color ?? .accentColor)
                .clipShape(.rect(cornerRadius: 5))
                .font(.subheadline)
                .fontDesign(.rounded)
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(component.name)
                .foregroundStyle(isSelected ? .white : .primary)
        }
        
        .padding(4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .draggableIfPresent(TransferableComponent(component: component), onDragInitiated: LibraryPanelManager.hide)
        .background(isSelected ? Color.blue : Color.clear)
        .clipShape(.rect(cornerRadius: 8))
        .onTapGesture {
            selectedComponentID = component.uuid
        }
        .preventWindowMove()
    }
}
