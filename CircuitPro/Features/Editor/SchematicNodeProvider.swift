//
//  SchematicNodeProvider.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/19/25.
//

import Foundation

/// A concrete implementation of `NodeProvider` that knows how to build the scene graph for the schematic editor.
///
/// This struct is the dedicated "factory" for creating a renderable node tree from a `CircuitDesign` data model.
/// It holds its own application-specific context, such as the wire engine, which is required during the build process.
struct SchematicNodeProvider: NodeProvider {
    /// The `SchematicNodeProvider` works with the `CircuitDesign` as its source of truth.
    typealias DataSource = CircuitDesign

    // MARK: - Dependencies

    /// The schematic wire engine that the generated nodes can query.
    private let wireEngine: WireEngine

    /// Initializes the provider with the dependencies it needs to build the scene graph.
    /// - Parameter wireEngine: The wire engine for the schematic editor.
    init(wireEngine: WireEngine) {
        self.wireEngine = wireEngine
    }

    // MARK: - NodeProvider Conformance

    /// The primary build method required by the `NodeProvider` protocol.
    ///
    /// This function orchestrates the entire process of creating the schematic's scene graph.
    /// - Parameters:
    ///   - source: The `CircuitDesign` data model to build from.
    ///   - context: The generic build context from CanvasKit (not used by the schematic provider).
    /// - Returns: An array of `BaseNode`s representing the complete schematic scene.
    @MainActor
    func buildNodes(from source: CircuitDesign, context: BuildContext) async -> [BaseNode] {
        // Step 1: Build the individual SymbolNodes from the component instances.
        let symbolNodes = generateSymbolNodes(from: source)

        // Step 2: Return only symbol nodes. Wires are now rendered from the unified graph.
        return symbolNodes
    }

    // MARK: - Private Helper Methods

    /// Generates an array of `SymbolNode`s from the `ComponentInstance` data in the design.
    @MainActor
    private func generateSymbolNodes(from design: CircuitDesign) -> [SymbolNode] {
        var symbolNodes: [SymbolNode] = []
        symbolNodes.reserveCapacity(design.componentInstances.count)

        for inst in design.componentInstances {
            guard inst.symbolInstance.definition != nil else { continue }

            if let node = SymbolNode(
                id: inst.id,
                instance: inst.symbolInstance,
                wireEngine: wireEngine
            ) {
                symbolNodes.append(node)
            }
        }

        return symbolNodes
    }
}
