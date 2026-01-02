//
//  CanvasScene.swift
//  CircuitPro
//
//  Created by Codex on 12/30/25.
//

import Observation

@MainActor
@Observable
final class CanvasScene {
    var graph: CanvasGraph
    let store: CanvasStore?

    init(graph: CanvasGraph, store: CanvasStore?) {
        self.graph = graph
        self.store = store
    }
}
