//
//  CanvasItem.swift
//  CircuitPro
//
//  Created by Codex on 12/30/25.
//

import Foundation

/// A lightweight, ID-stable item that can be materialized into the canvas graph.
protocol CanvasItem: Identifiable where ID == UUID {
    var elementID: GraphElementID { get }
    func apply(to graph: CanvasGraph)
}
