//
//  NavigatorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 30.05.25.
//

import SwiftUI

enum NavigatorViewTab: Displayable {
    case projectNavigator
    case directoryExplorer
    case ruleChecks
    
    var label: String {
        switch self {
        case .projectNavigator:
            return "Project Navigator"
        case .directoryExplorer:
            return "Directory Explorer"
        case .ruleChecks:
            return "Rule Checks"
        }
    }
    
    var icon: String {
        switch self {
        case .projectNavigator:
            return AppIcons.projectNavigator
        case .directoryExplorer:
            return AppIcons.directoryExplorer
        case .ruleChecks:
            return AppIcons.ruleChecks
        }
    }
}

struct NavigatorView: View {
  
    
    @State private var selectedTab: NavigatorViewTab = .projectNavigator
    var document: CircuitProjectDocument
    
    

    var body: some View {
        
        VStack(spacing: 0) {
            Divider().foregroundStyle(.quaternary)

            HStack(spacing: 17) {
                ForEach(NavigatorViewTab.allCases.dropLast()) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Image(systemName: tab.icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 13, height: 13)
                            .foregroundStyle(selectedTab == tab ? .blue : .secondary)

                    }
                    .buttonStyle(.plain)
                    .help(tab.label)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .foregroundStyle(.secondary)

            Divider().foregroundStyle(.quaternary)

            
            switch selectedTab {
            case .projectNavigator:
                ProjectNavigatorView(document: document)
            default:
                Group {
                    Text("Default")
                    Spacer()
                }
            }
         
        }
        
      
    }
}
