//
//  WireRequestNode.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/7/25.
//

import SwiftUI

// This is a simple data-carrying class, not a real visual element.
final class WireRequestNode: BaseNode {
    let from: CGPoint
    let to: CGPoint
    let strategy: WireGraph.WireConnectionStrategy

    init(from: CGPoint, to: CGPoint, strategy: WireGraph.WireConnectionStrategy) {
        self.from = from
        self.to = to
        self.strategy = strategy
        super.init()
    }
}
