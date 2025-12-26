//
//  GraphNodeComponent.swift
//  CircuitPro
//
//  Created by Codex on 9/22/25.
//

import Foundation

/// Marks a graph node as representing a scene node for hit-testing.
struct GraphNodeComponent: GraphComponent {
    enum Kind {
        case node
        case text

        var priority: Int {
            switch self {
            case .text: return 3
            case .node: return 2
            }
        }
    }

    var kind: Kind
}
