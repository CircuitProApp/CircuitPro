//
//  UserComponentsView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/18/25.
//

import SwiftUI
import SwiftDataPacks

struct UserComponentsView: View {
    
    @Environment(LibraryManager.self) private var manager
    
    @UserContext private var userContext
    
    @Query private var userComponents: [Component]
    
    @State private var selectedComponentID: UUID?
    
    private var filteredComponents: [Component] {
        if manager.searchText.isEmpty {
            return userComponents
        } else {
            return userComponents.filter { $0.name.localizedCaseInsensitiveContains(manager.searchText) }
        }
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
