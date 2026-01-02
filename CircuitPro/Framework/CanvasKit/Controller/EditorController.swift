//
//  EditorController.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/19/25.
//

import SwiftUI

/// The protocol that all high-level editor controllers must conform to.
///
/// An `EditorController` acts as the single source of truth for a `CanvasView`.
/// It is responsible for owning the editor's state and providing the necessary
/// configurations for rendering and interaction.
@MainActor
protocol EditorController {

    var selectedTool: CanvasTool { get set }
}
