//
//  AllComponentsView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/11/25.
//

import SwiftUI
import SwiftDataPacks

struct AllComponentsView: View {
    
    @Environment(LibraryManager.self) private var manager
    @UserContext private var userContext
    
    @Query private var allComponents: [Component]
    
    @State private var selectedComponentID: UUID?
    
    private var filteredComponents: [Component] {
        if manager.searchText.isEmpty {
            return allComponents
        } else {
            return allComponents.filter { $0.name.localizedCaseInsensitiveContains(manager.searchText) }
        }
    }
    
    var body: some View {
        if filteredComponents.isNotEmpty {
            GroupedList {
                ForEach(ComponentCategory.allCases) { category in
                    // Filter the components for the current category.
                    let componentsInCategory = filteredComponents.filter { $0.category == category }
                    
                    if !componentsInCategory.isEmpty {
                        Section {
                            ForEach(componentsInCategory) { component in
                                ComponentListRowView(component: component, selectedComponentID: $selectedComponentID)
                            }
                        } header: {
                            Text(category.label)
                                .font(.caption)
                                .fontWeight(.light)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .groupedListConfiguration { configuration in
                configuration.isHudListStyle = true
                configuration.listHeaderPadding = .init(top: 2, leading: 8, bottom: 2, trailing: 8)
                configuration.listPadding = .all(7.5)
      
            }
        } else {
            Text("No Matches")
                .foregroundStyle(.secondary)
        }
    }
}
