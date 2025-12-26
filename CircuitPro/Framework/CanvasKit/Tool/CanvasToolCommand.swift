//
//  CanvasToolCommand.swift
//  CircuitPro
//
//  Created by Codex on 9/22/25.
//

import Foundation

/// A lightweight, domain-agnostic command that tools can use to perform graph-first actions.
struct CanvasToolCommand {
    let perform: (ToolInteractionContext, CanvasController) -> Void

    func execute(context: ToolInteractionContext, controller: CanvasController) {
        perform(context, controller)
    }
}
