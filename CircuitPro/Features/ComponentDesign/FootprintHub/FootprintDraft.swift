//
//  FootprintDraft.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/13/25.
//

import SwiftUI
import Observation

@MainActor
@Observable
final class FootprintDraft: Identifiable, Hashable {

    let id = UUID()

    /// The display name of the footprint, which can be edited by the user.
    var name: String

    /// The dedicated manager that holds the entire UI state for this draft's canvas,
    /// including nodes, selection, undo history, and tool state.
    var editor: CanvasEditorManager

    init(name: String) {
        self.name = name
        self.editor = CanvasEditorManager(textTarget: .footprint)
        self.editor.setupForFootprintEditing()
    }

    // Conformance to Hashable
    static func == (lhs: FootprintDraft, rhs: FootprintDraft) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
