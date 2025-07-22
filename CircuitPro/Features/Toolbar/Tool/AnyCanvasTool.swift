//
//  AnyCanvasTool.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 19.06.25.
//

import SwiftUI

struct AnyCanvasTool: CanvasTool {

    let id: String
    let symbolName: String
    let label: String

    private let _handleTap: (CGPoint, CanvasToolContext) -> CanvasToolResult
    private let _preview: (CGPoint, CanvasToolContext) -> ToolPreview?
    private let _handleEscape: () -> Void
    private let _handleBackspace: () -> Void
    private let _handleRotate: () -> Void
    private let _handleReturn: () -> CanvasToolResult
    private let box: ToolBoxBase          // <— keeps the ToolBox alive

     init<T: CanvasTool>(_ tool: T) {
         let storage = ToolBox(tool)       // class wrapper, reference-type
         self.box = storage

         id         = tool.id
         symbolName = tool.symbolName
         label      = tool.label

        // ----- handleTap ----------------------------------------------------
        _handleTap = { loc, ctx in
            var inner = storage.tool             // 1 – copy out
            let result = inner.handleTap(at: loc, context: ctx) // 2 – mutate
            storage.tool = inner                 // 3 – store back
            return result                       // 4
        }

        // ----- preview ------------------------------------------------------
        _preview = { mouse, ctx in
            var inner = storage.tool             // 1
            let result = inner.preview(mouse: mouse, context: ctx) // 2
            storage.tool = inner                 // 3
            return result
        }

        // ----- handleEscape -------------------------------------------------
        _handleEscape = {
            var inner = storage.tool
            inner.handleEscape()
            storage.tool = inner
        }

        // ----- handleBackspace ----------------------------------------------
        _handleBackspace = {
            var inner = storage.tool
            inner.handleBackspace()
            storage.tool = inner
        }

        // ----- handleRotate -------------------------------------------------
        _handleRotate = {
            var inner = storage.tool
            inner.handleRotate()
            storage.tool = inner
        }

        // ----- handleReturn -------------------------------------------------
        _handleReturn = {
            var inner = storage.tool
            let result = inner.handleReturn()
            storage.tool = inner
            return result
        }
     }

     // simple forwarders -------------------------------------------------------
     mutating func handleTap(at point: CGPoint, context: CanvasToolContext) -> CanvasToolResult {
         _handleTap(point, context)
     }

    mutating func preview(mouse: CGPoint, context: CanvasToolContext) -> ToolPreview? {
        _preview(mouse, context)
    }

    mutating func handleEscape() {
        _handleEscape()
    }

    mutating func handleBackspace() {
        _handleBackspace()
    }

    mutating func handleRotate() {
        _handleRotate()
    }

    mutating func handleReturn() -> CanvasToolResult {
        _handleReturn()
    }

    static func == (lhs: AnyCanvasTool, rhs: AnyCanvasTool) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

private protocol ToolBoxBase: AnyObject {}

final class ToolBox<T: CanvasTool>: ToolBoxBase {
    var tool: T
    init(_ canvasTool: T) { tool = canvasTool }
}