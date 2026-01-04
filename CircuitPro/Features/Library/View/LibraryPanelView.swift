//
//  LibraryPanelView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/11/25.
//

import SwiftUI
import SwiftData

struct LibraryPanelView: View {
    
    @State private var libraryManager: LibraryManager = LibraryManager()
    
    var body: some View {
        @Bindable var bindableManager = libraryManager
        VStack(alignment: .leading, spacing: 0) {
            LibrarySearchView(searchText: $bindableManager.searchText)
            Divider()
            LibraryModeView(selectedMode: $bindableManager.selectedMode)
            Divider()
            HStack(spacing: 0) {
                Group {
                    switch libraryManager.selectedMode {
                    case .all:
                        ComponentListView()
                    case .user:
                        ComponentListView()
                            .filterContainer(for: .mainStore)
                    case .packs:
                        PacksView()
                    }
                }
                .frame(width: 272)
                .frame(maxHeight: .infinity)
                Divider()
                Group {
                    switch libraryManager.selectedMode {
                    case .all, .user:
                        ComponentDetailView()
                    case .packs:
                        PackDetailView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 682, minHeight: 373)
        .environment(libraryManager)
    }
}
