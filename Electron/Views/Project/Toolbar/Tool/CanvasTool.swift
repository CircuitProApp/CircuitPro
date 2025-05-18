//
//  CanvasTool.swift
//  Electron
//
//  Created by Giorgi Tchelidze on 4/30/25.
//
import SwiftUI

protocol CanvasTool: Hashable {
    var id: String { get }
    var symbolName: String { get }
    var label: String { get }

    mutating func handleTap(at location: CGPoint, context: CanvasToolContext) -> CanvasElement?

    // New CoreGraphics preview method
    mutating func drawPreview(in ctx: CGContext, mouse: CGPoint, context: CanvasToolContext)
}


extension CanvasTool {
    mutating func handleTap(at location: CGPoint) -> CanvasElement? {
        handleTap(at: location, context: CanvasToolContext())
    }
}

private protocol ToolBoxBase: AnyObject {}
final class ToolBox<T: CanvasTool>: ToolBoxBase {
    var tool: T
    init(_ t: T) { tool = t }
}


struct AnyCanvasTool: CanvasTool {
    let id: String
    let symbolName: String
    let label: String

    private let _handleTap   : (CGPoint, CanvasToolContext) -> CanvasElement?
     private let _drawPreview : (CGContext, CGPoint, CanvasToolContext) -> Void
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

         // ----- drawPreview ---------------------------------------------------
         _drawPreview = { cg, mouse, ctx in
             var inner = storage.tool             // 1
             inner.drawPreview(in: cg, mouse: mouse, context: ctx) // 2
             storage.tool = inner                 // 3
         }
     }

     // simple forwarders -------------------------------------------------------
     mutating func handleTap(at p: CGPoint,
                             context: CanvasToolContext) -> CanvasElement? {
         _handleTap(p, context)
     }
     mutating func drawPreview(in cg: CGContext,
                               mouse: CGPoint,
                               context: CanvasToolContext) {
         _drawPreview(cg, mouse, context)
     }

    static func == (a: AnyCanvasTool, b: AnyCanvasTool) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}



struct CanvasToolContext {
    var existingPinCount: Int = 0
    var existingPadCount: Int = 0
    var selectedLayer: LayerKind = .copper
}



enum CanvasToolRegistry {
    static let base: [AnyCanvasTool] = [
        AnyCanvasTool(CursorTool())
    ]
    static let graphicsTools: [AnyCanvasTool] = [
        AnyCanvasTool(LineTool()),
        AnyCanvasTool(RectangleTool()),
        AnyCanvasTool(CircleTool())
    ]
    
    static let symbolDesignTools: [AnyCanvasTool] =
       base + graphicsTools + [AnyCanvasTool(PinTool())] + [AnyCanvasTool(RulerTool())]
    
    static let footprintDesignTools: [AnyCanvasTool] =
       base + graphicsTools + [AnyCanvasTool(PadTool())] + [AnyCanvasTool(RulerTool())]

}
