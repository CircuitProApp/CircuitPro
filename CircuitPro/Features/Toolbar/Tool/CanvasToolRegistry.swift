//
//  CanvasToolRegistry.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 5/19/25.
//

enum CanvasToolRegistry {
    static let cursor: [AnyCanvasTool] = [
        AnyCanvasTool(CursorTool())
    ]

    static let ruler: [AnyCanvasTool] = [
        AnyCanvasTool(RulerTool())
    ]

    static let graphicsTools: [AnyCanvasTool] = [
        AnyCanvasTool(LineTool()),
        AnyCanvasTool(RectangleTool()),
        AnyCanvasTool(CircleTool())
    ]

    static let symbolDesignTools: [AnyCanvasTool] =
    cursor + graphicsTools + [AnyCanvasTool(PinTool())] + ruler

    static let footprintDesignTools: [AnyCanvasTool] =
    cursor + graphicsTools + [AnyCanvasTool(PadTool())] + ruler

}
