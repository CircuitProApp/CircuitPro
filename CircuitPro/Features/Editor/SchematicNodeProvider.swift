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
/// It holds its own application-specific context, such as the `schematicGraph`, which is required during the build process.
struct SchematicNodeProvider: NodeProvider {
    /// The `SchematicNodeProvider` works with the `CircuitDesign` as its source of truth.
    typealias DataSource = CircuitDesign

    // MARK: - Dependencies
    
    /// A reference to the ProjectManager is needed to access shared services,
    /// primarily the `generateString` utility which can resolve pending ECO values.
    private let projectManager: ProjectManager
    
    /// The specific instance of the schematic graph that the generated nodes will be associated with.
    private let schematicGraph: WireGraph
    
    /// Initializes the provider with the dependencies it needs to build the scene graph.
    /// - Parameters:
    ///   - projectManager: The central project manager.
    ///   - schematicGraph: The graph controller for the schematic editor.
    init(projectManager: ProjectManager, schematicGraph: WireGraph) {
        self.projectManager = projectManager
        self.schematicGraph = schematicGraph
    }

    // MARK: - NodeProvider Conformance

    /// The primary build method required by the `NodeProvider` protocol.
    ///
    /// This function orchestrates the entire process of creating the schematic's scene graph.
    /// - Parameters:
    ///   - source: The `CircuitDesign` data model to build from.
    ///   - context: The generic build context from CanvasKit (not used by the schematic provider).
    /// - Returns: An array of `BaseNode`s representing the complete schematic scene.
    func buildNodes(from source: CircuitDesign, context: BuildContext) async -> [BaseNode] { // Marked as async
        // Step 1: Ensure our internal graph is fully synchronized with the latest data from the design model.
        // This must be done before creating any nodes that depend on the graph's state (like SymbolNode).
        updateGraph(from: source)

        // Step 2: Build the individual SymbolNodes from the component instances.
        let symbolNodes = await generateSymbolNodes(from: source) // Await the async call
        
        // Step 3: Create the single node responsible for rendering all the wires in the graph.
        let graphNode = SchematicGraphNode(graph: self.schematicGraph)
        graphNode.syncChildNodesFromModel()
        
        // Step 4: Combine all nodes into a single array for the canvas to render.
        return symbolNodes + [graphNode]
    }
    
    // MARK: - Private Helper Methods
    
    /// Updates the internal `schematicGraph` to match the state of the provided `CircuitDesign`.
    /// This involves rebuilding wire connections and synchronizing all component pins.
    private func updateGraph(from design: CircuitDesign) {
        schematicGraph.build(from: design.wires)
        for inst in design.componentInstances {
            guard let symbolDef = inst.definition?.symbol else { continue }
            schematicGraph.syncPins(for: inst.symbolInstance, of: symbolDef, ownerID: inst.id)
        }
    }
    
    /// Generates an array of `SymbolNode`s from the `ComponentInstance` data in the design.
    private func generateSymbolNodes(from design: CircuitDesign) async -> [SymbolNode] { // Marked as async
        return await withTaskGroup(of: SymbolNode?.self) { group in
            for inst in design.componentInstances {
                group.addTask {
                    // A SymbolNode can only be created if it has a valid, hydrated SymbolInstance.
                    // inst.symbolInstance is not optional, so we only need to check its definition.
                    guard inst.symbolInstance.definition != nil else {
                        return nil
                    }
                    
                    // Generate the necessary text objects for this symbol.
                    let renderableTexts = await generateRenderableTexts(for: inst) // Await the async call
                    
                    // Initialize the SymbolNode.
                    return SymbolNode(id: inst.id, instance: inst.symbolInstance, renderableTexts: renderableTexts, graph: self.schematicGraph)
                }
            }
            var symbolNodes: [SymbolNode] = []
            for await node in group {
                if let node = node {
                    symbolNodes.append(node)
                }
            }
            return symbolNodes
        }
    }
    
    /// Generates an array of `RenderableText` objects for a single `ComponentInstance`.
    /// This involves creating the final display string for each piece of dynamic text.
    private func generateRenderableTexts(for inst: ComponentInstance) async -> [RenderableText] { // Marked as async
        return await withTaskGroup(of: RenderableText?.self) { group in
            for resolvedModel in inst.symbolInstance.resolvedItems {
                group.addTask {
                    // This is the key reason the provider needs a reference to the ProjectManager.
                    // `generateString` contains the logic to correctly display pending ECO values.
                    let displayString = await projectManager.generateString(for: resolvedModel, component: inst) // Await the main actor call
                    return RenderableText(model: resolvedModel, text: displayString)
                }
            }
            var renderableTexts: [RenderableText] = []
            for await text in group {
                if let text = text {
                    renderableTexts.append(text)
                }
            }
            return renderableTexts
        }
    }
}
