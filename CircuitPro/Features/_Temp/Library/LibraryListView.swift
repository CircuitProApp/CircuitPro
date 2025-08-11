//
//  LibraryListView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/11/25.
//

import SwiftUI

struct LibraryListView: View {
    
    var filteredComponents: [Component] = []
    @Binding var selectedComponentID: UUID?
    
    init(filteredComponents: [Component], selectedComponentID: Binding<UUID?>) {
        self.filteredComponents = filteredComponents
        self._selectedComponentID = selectedComponentID

          
    }
    
    
    
    var body: some View {
        if filteredComponents.isNotEmpty {
            List(selection: $selectedComponentID) {
                ForEach(ComponentCategory.allCases) { category in
                    // Filter the components for the current category.
                    let componentsInCategory = filteredComponents.filter { $0.category == category }

                    if !componentsInCategory.isEmpty {
                        Section(header:    Text(category.label)) {
                            ForEach(componentsInCategory) { component in
                                ComponentListRowView(component: component)
                                    .tag(component.uuid)
                                    .listRowSeparatorTint(.secondary.opacity(0.25))
                            }
                        }
 
                          
                        
                    }
                }
            }
            .frame(width: 272)
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
                  .background(Color.clear)
            
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
    
    var body: some View {
        HStack {
            Text(component.referenceDesignatorPrefix)
            
                .frame(width: 32, height: 32)
                .background(.teal)
                .clipShape(.rect(cornerRadius: 5))
                .font(.subheadline)
                .fontDesign(.rounded)
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(component.name)
        }
        .draggableIfPresent(TransferableComponent(component: component), symbol: nil, onDragInitiated: LibraryPanelManager.hide)
    }
}
