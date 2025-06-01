//
//  UtilityAreaView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 30.05.25.
//

import SwiftUI

enum UtilityAreaTab: Displayable {
    case design
    case appLibrary
    case userLibrary
    
    var label: String {
        switch self {
        case .design:
            return "Design Library"
        case .appLibrary:
            return "App Library"
        case .userLibrary:
            return "User Library"
        }
    }
    
    var icon: String {
        switch self {
        case .design:
            return AppIcons.design.replacingOccurrences(of: ".fill", with: "")
        case .appLibrary:
            return "books.vertical"
        case .userLibrary:
            return "person"
        }
    }
}

struct UtilityAreaView: View {
    
    @State private var selectedCategory: ComponentCategory?
    @State private var selectedTab: UtilityAreaTab = .design
    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 12.5) {
                ForEach(UtilityAreaTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Image(systemName: tab == selectedTab ? "\(tab.icon).fill" : tab.icon)
                            .font(.system(size: 12.5))
                            .foregroundStyle(selectedTab == tab ? .blue : .secondary)
                            .if(tab == .design) { view in
                                view.padding(.top, 12.5)
                            }
                    }
                    .buttonStyle(.plain)
                    .help(tab.label)

               
                }
                Spacer()
            }
            .frame(width: 40)
  
            Divider()
                .foregroundStyle(.quaternary)
            Group {
                switch selectedTab {
                case .design:
                    Text("Design library")
                case .appLibrary:
                    List(ComponentCategory.allCases, id: \.self, selection: $selectedCategory) { category in
                        HStack(spacing: 5) {
                            Image(systemName: "text.page")
                                .foregroundStyle(selectedCategory == category ? .primary : .secondary)
                            Text(category.label)
                        }
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.inset)
                    .scrollContentBackground(.hidden)
                case .userLibrary:
                    Text("User library")
                }
            }

            .frame(width: 240)
          
      
            Divider()
                .foregroundStyle(.quaternary)
            Text("Content Area")
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    UtilityAreaView()
}
