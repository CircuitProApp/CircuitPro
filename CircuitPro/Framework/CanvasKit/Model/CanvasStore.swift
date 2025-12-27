//
//  CanvasStore.swift
//  CircuitPro
//
//  Created by Codex on 9/20/25.
//

import Foundation
import Observation

/// A generic, domain-agnostic state container for a canvas scene graph.
@MainActor
@Observable
final class CanvasStore {
    var selection: Set<UUID> = [] {
        didSet {
            guard selection != oldValue else { return }
            onDelta?(.selectionChanged(selection))
            invalidate()
        }
    }
    var revision: Int = 0
    var onDelta: ((CanvasStoreDelta) -> Void)?

    func invalidate() {
        revision &+= 1
    }
}
