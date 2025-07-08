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

    private let _handleTap: (CGPoint, CanvasToolContext) -> CanvasElement?
    private let _drawPreview: (CGContext, CGPoint, CanvasToolContext) -> Void
    private let _handleEscape: () -> Void
    private let _handleBackspace: () -> Void
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
            let element = inner.handleTap(at: loc, context: ctx) // 2 – mutate
            storage.tool = inner                 // 3 – store back
            return element                       // 4
        }

        // ----- drawPreview --------------------------------------------------
        _drawPreview = { cgCTX, mouse, ctx in
            var inner = storage.tool             // 1
            inner.drawPreview(in: cgCTX, mouse: mouse, context: ctx) // 2
            storage.tool = inner                 // 3
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
     }

     // simple forwarders -------------------------------------------------------
     mutating func handleTap(at point: CGPoint, context: CanvasToolContext) -> CanvasElement? {
         _handleTap(point, context)
     }
    mutating func drawPreview(in cgCTX: CGContext, mouse: CGPoint, context: CanvasToolContext) {
        _drawPreview(cgCTX, mouse, context)
    }

    mutating func handleEscape() {
        _handleEscape()
    }

    mutating func handleBackspace() {
        _handleBackspace()
    }

    static func == (lhs: AnyCanvasTool, rhs: AnyCanvasTool) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

private protocol ToolBoxBase: AnyObject {}

final class ToolBox<T: CanvasTool>: ToolBoxBase {
    var tool: T
    init(_ canvasTool: T) { tool = canvasTool }
}
