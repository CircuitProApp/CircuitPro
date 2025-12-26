//
//  NodeProvider.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/19/25.
//

import Foundation

/// Defines a type that can construct a scene graph (`[BaseNode]`) from a specific data model.
///
/// This is the core protocol for decoupling the canvas rendering engine from the application's
/// specific data structures. It acts as a "translator" or "factory" that takes a high-level
/// data model (the `DataSource`) and produces a low-level, renderable node tree.
protocol NodeProvider {

    /// The source data type this provider works with (e.g., a `CircuitDesign` or a custom scene struct).
    /// It must be `Identifiable` so that SwiftUI can efficiently track changes to it.
    associatedtype DataSource: Identifiable



    /// The primary build method. The canvas system will call this function to generate the complete
    /// list of nodes whenever the `DataSource` changes.
    ///
    /// - Parameters:
    ///   - source: The application's data model to build from.
    ///   - context: The generic context required by the provider to perform its work.
    /// - Returns: An array of `BaseNode`s representing the complete scene.
    func buildNodes(from source: DataSource, context: BuildContext) async -> [BaseNode]
}

/// A context object containing generic, framework-level information that might be needed to build the nodes.
///
/// This struct is defined within CanvasKit and should remain application-agnostic. For example, it could
/// contain information about the active canvas layers, which is relevant for a layout editor but managed
/// by the generic `CanvasKit` framework.
struct BuildContext {
    let activeLayers: [CanvasLayer]

    // This is intentionally minimal. Application-specific context (like a wire engine)
    // should be held by the concrete `NodeProvider` implementation itself, not passed in here.
}
