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
/// It is responsible for owning the editor's state, building the node tree,
/// and providing the necessary configurations for rendering and interaction.
@MainActor
protocol EditorController {
    
    /// The final, renderable scene graph. The `CanvasView` will observe this property
    /// and automatically re-render when it changes.
    var nodes: [BaseNode] { get }
    
    var selectedTool: CanvasTool { get set }
    
    // For now, we'll keep the static configuration in the View. This protocol
    // will grow as we continue to refactor. The core responsibility is providing `nodes`.
    
    /// A method for the Inspector or other views to find a node by its ID.
    func findNode(with id: UUID) -> BaseNode?
}
