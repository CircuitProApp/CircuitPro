//
//  NavigatorTab.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/28/25.
//

import SwiftUI

enum NavigatorTab: SidebarTab {

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
            return CircuitProSymbols.Workspace.projectNavigator
        case .directoryExplorer:
            return CircuitProSymbols.Workspace.directoryExplorer
        case .ruleChecks:
            return CircuitProSymbols.Workspace.ruleChecks
        }
    }
}
