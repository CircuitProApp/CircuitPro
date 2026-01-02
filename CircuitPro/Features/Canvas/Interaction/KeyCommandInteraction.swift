//
//  KeyCommandInteraction.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/9/25.
//

import AppKit
import Carbon.HIToolbox  // For kVK constants
import SwiftUI

/// An interaction that handles global keyboard commands like Escape, Return, Delete, and Rotate.
/// It prioritizes sending commands to the active tool first, falling back to graph actions
/// (like deleting selected elements) if the tool doesn't handle the command.
struct KeyCommandInteraction: CanvasInteraction {

    private let deleteComponentInstances: ((Set<UUID>) -> Bool)?

    init(
        deleteComponentInstances: ((Set<UUID>) -> Bool)? = nil
    ) {
        self.deleteComponentInstances = deleteComponentInstances
    }

    func keyDown(with event: NSEvent, context: RenderContext, controller: CanvasController) -> Bool
    {
        // Use key codes for non-character keys like Escape, Return, and Delete.
        switch Int(event.keyCode) {

        case kVK_Escape:
            return handleEscape(controller: controller)

        case kVK_Return, kVK_ANSI_KeypadEnter:
            return handleReturn(context: context, controller: controller)

        case kVK_Delete, kVK_ForwardDelete:
            return handleDelete(context: context, controller: controller)

        default:
            // For character keys like 'r', check the character itself.
            guard let chars = event.charactersIgnoringModifiers?.lowercased() else {
                return false
            }
            if chars == "r" {
                return handleRotate(context: context, controller: controller)
            }
            return false
        }
    }

    /// Handles the Escape key.
    /// It first offers the event to the active tool. If the tool doesn't handle it,
    /// it deselects the tool, effectively returning to the default cursor state.
    private func handleEscape(controller: CanvasController) -> Bool {
        guard let tool = controller.selectedTool, !(tool is CursorTool) else {
            // If there's no special tool active, Escape does nothing.
            return false
        }

        // If the tool clears its own state (e.g., a multi-point line tool), it returns true.
        if tool.handleEscape() {
            // The tool handled it, nothing more to do.
        } else {
            // If the tool didn't handle it, we assume the user wants to cancel the tool itself.
            // Setting the tool to nil will cause the view to fall back to the default tool.
            controller.selectedTool = nil
        }
        return true  // We consumed the Escape key event.
    }

    /// Handles the Return/Enter key.
    /// This is typically used to finalize a tool's operation.
    private func handleReturn(context: RenderContext, controller: CanvasController) -> Bool {
        guard let tool = controller.selectedTool else { return false }

        let result = tool.handleReturn()

        // This logic is similar to ToolInteraction's mouseDown, handling tool results.
        switch result {
        case .noResult:
            return false
        case .command(let command):
            command.execute(
                context: ToolInteractionContext(clickCount: 0, renderContext: context),
                controller: controller)
            return true
        case .newPrimitive(let primitive):
            if let itemsBinding = context.environment.items {
                var items = itemsBinding.wrappedValue
                items.append(primitive)
                itemsBinding.wrappedValue = items
                return true
            } else {
                let graph = context.graph
                let nodeID = NodeID(primitive.id)
                if !graph.nodes.contains(nodeID) {
                    graph.addNode(nodeID)
                }
                graph.setComponent(primitive, for: nodeID)
                return true
            }
        }
    }

    /// Handles the Delete/Backspace key.
    /// It first offers the event to the active tool (e.g., to delete the last point).
    /// If the tool doesn't handle it, it deletes the currently selected nodes.
    private func handleDelete(context: RenderContext, controller: CanvasController) -> Bool {
        // Prioritize the active tool.
        if let tool = controller.selectedTool, !(tool is CursorTool) {
            // Allow the tool to perform a "backspace" action.
            tool.handleBackspace()
            return true  // Assume the tool handled it.
        }

        // If no tool handled it, perform the standard "delete selection" action.
        let graph = context.graph
        guard !graph.selection.isEmpty else { return false }
        let selectedNodeIDs = graph.selection.compactMap { $0.nodeID }
        let selectedEdgeIDs = graph.selection.compactMap { $0.edgeID }
        let selectedIDs = Set(selectedNodeIDs.map(\.rawValue) + selectedEdgeIDs.map(\.rawValue))
        let selectedItemIDs = Set(selectedNodeIDs.map(\.rawValue))
        let hasWireSelection = graph.selection.contains { id in
            switch id {
            case .node(let nodeID):
                return graph.component(WireVertexComponent.self, for: nodeID) != nil
            case .edge(let edgeID):
                return graph.component(WireEdgeComponent.self, for: edgeID) != nil
            }
        }

        if hasWireSelection,
            let wireEngine = context.environment.connectionEngine as? WireEngine
        {
            Task { @MainActor in
                wireEngine.delete(items: selectedIDs)
            }
            graph.selection = []
            Task { @MainActor in
                context.environment.canvasStore?.selection.subtract(Set(selectedNodeIDs.map(\.rawValue)))
            }
            return true
        }

        let hasTraceSelection = graph.selection.contains { id in
            switch id {
            case .node(let nodeID):
                return graph.component(TraceVertexComponent.self, for: nodeID) != nil
            case .edge(let edgeID):
                return graph.component(TraceEdgeComponent.self, for: edgeID) != nil
            }
        }

        if hasTraceSelection,
            let traceEngine = context.environment.connectionEngine as? TraceEngine
        {
            Task { @MainActor in
                traceEngine.delete(items: selectedIDs)
            }
            graph.selection = []
            Task { @MainActor in
                context.environment.canvasStore?.selection.subtract(Set(selectedNodeIDs.map(\.rawValue)))
            }
            return true
        }

        if let itemsBinding = context.environment.items {
            let items = itemsBinding.wrappedValue
            let componentInstanceIDs = Set(
                items.compactMap { item in
                    if selectedItemIDs.contains(item.id), item is ComponentInstance {
                        return item.id
                    }
                    return nil
                }
            )
            if !componentInstanceIDs.isEmpty, let deleteComponentInstances {
                if deleteComponentInstances(componentInstanceIDs) {
                    graph.selection = []
                    Task { @MainActor in
                        context.environment.canvasStore?.selection.subtract(
                            Set(selectedNodeIDs.map(\.rawValue)))
                    }
                    return true
                }
            }

            let remaining = items.filter { !selectedItemIDs.contains($0.id) }
            if remaining.count != items.count {
                itemsBinding.wrappedValue = remaining
                graph.selection = []
                Task { @MainActor in
                    context.environment.canvasStore?.selection.subtract(
                        Set(selectedNodeIDs.map(\.rawValue)))
                }
                return true
            }
        }

        for element in graph.selection {
            guard case .node(let nodeID) = element else { continue }
            graph.removeNode(nodeID)
        }
        graph.selection = []
        Task { @MainActor in
            context.environment.canvasStore?.selection.subtract(Set(selectedNodeIDs.map(\.rawValue)))
        }
        return true
    }

    /// Handles the 'R' key for rotation.
    /// It first offers the event to the active tool. If no tool handles it,
    /// it attempts to rotate the currently selected nodes.
    private func handleRotate(context: RenderContext, controller: CanvasController) -> Bool {
        // Prioritize the active tool.
        if let tool = controller.selectedTool, !(tool is CursorTool) {
            tool.handleRotate()
            return true
        }

        let graph = context.graph
        guard !graph.selection.isEmpty else { return false }
        if let itemsBinding = context.environment.items {
            var items = itemsBinding.wrappedValue
            var didRotate = false
            for index in items.indices {
                guard graph.selection.contains(.node(NodeID(items[index].id))) else { continue }
                if var primitive = items[index] as? AnyCanvasPrimitive {
                    primitive.rotation += .pi / 2
                    items[index] = primitive
                    didRotate = true
                }
            }
            if didRotate {
                itemsBinding.wrappedValue = items
                return true
            }
        }

        for element in graph.selection {
            guard case .node(let nodeID) = element,
                var primitive = graph.component(AnyCanvasPrimitive.self, for: nodeID)
            else {
                continue
            }
            primitive.rotation += .pi / 2
            graph.setComponent(primitive, for: nodeID)
        }
        return true
    }
}
