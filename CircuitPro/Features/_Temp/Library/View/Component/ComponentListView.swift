//
//  ComponentListView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/18/25.
//

import SwiftUI
import SwiftDataPacks

struct ComponentListView: View {
    
    @Environment(LibraryManager.self)
    private var libraryManager
    
    @UserContext private var userContext
    
    @Query private var userComponents: [Component]
    
    private var filteredComponents: [Component] {
        if libraryManager.searchText.isEmpty {
            return userComponents
        } else {
            return userComponents.filter { $0.name.localizedCaseInsensitiveContains(libraryManager.searchText) }
        }
    }
    
    var body: some View {
        @Bindable var libraryManager = libraryManager
        if filteredComponents.isNotEmpty {
            GroupedList(selection: $libraryManager.selectedComponent) {
                ForEach(ComponentCategory.allCases) { category in
                    // Filter the components for the current category.
                    let componentsInCategory = filteredComponents.filter { $0.category == category }
                    
                    if !componentsInCategory.isEmpty {
                        Section {
                            ForEach(componentsInCategory) { component in
                                ComponentListRowView(component: component, isSelected: libraryManager.selectedComponent == component)
                                    .listID(component)
                                    .contextMenu {
                                        Button("Delete Component") {
                                            userContext.delete(component)
                                        }
                                    }
                            }
                        } header: {
                            Text(category.label)
                                .listHeaderStyle()
                            
                        }
                    }
                }
            }
            .listConfiguration { configuration in
                configuration.headerStyle = .hud
                configuration.headerPadding = .init(top: 2, leading: 8, bottom: 2, trailing: 8)
                configuration.listPadding = .all(8)
                configuration.listRowPadding = .all(4)
                configuration.selectionCornerRadius = 8
      
            }
            
        } else {
            Text("No Matches")
                .foregroundStyle(.secondary)
        }
    }
}
