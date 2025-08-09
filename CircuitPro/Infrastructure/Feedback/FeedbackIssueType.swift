//
//  FeedbackIssueType.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/8/25.
//

import SwiftUI

enum FeedbackIssueType: Displayable {
    case bug
    case featureRequest
    case uiIssue
    case performance
    case other
    
    var label: String {
        switch self {
        case .bug: return "Bug"
        case .featureRequest: return "Feature Request"
        case .uiIssue: return "UI Issue"
        case .performance: return "Performance"
        case .other: return "Other"
        }
    }
}
