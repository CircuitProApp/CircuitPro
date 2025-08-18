//
//  AllComponentsView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/11/25.
//

import SwiftUI
import SwiftDataPacks

struct AllComponentsView: View {
    
    @UserContext private var userContext
    
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
                                    ComponentListRowView(component: component, selectedComponentID: $selectedComponentID)
                                        .padding(.horizontal, 6)
                                        .contentShape(.rect)
#if DEBUG
                                        .contextMenu {
                                            Button("Delete") {
                                                userContext.delete(component)
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
            }
        } else {
            Text("No Matches")
                .foregroundStyle(.secondary)
        }
    }
}
