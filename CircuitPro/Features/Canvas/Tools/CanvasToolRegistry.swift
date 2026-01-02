//
//  CanvasToolRegistry.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 5/19/25.
//

enum CanvasToolRegistry {

    static let cursor: [CanvasTool] = [
        CursorTool()
    ]

    static let ruler: [CanvasTool] = [
//        RulerTool()
    ]

    static let text: [CanvasTool] = [
        TextTool()
    ]

    static let graphicsTools: [CanvasTool] = [
        LineTool(),
        RectangleTool(),
        CircleTool()
    ]

    static let symbolDesignTools: [CanvasTool] =
        cursor + graphicsTools + [PinTool()] + ruler

    static let footprintDesignTools: [CanvasTool] =
        cursor + graphicsTools + [PadTool()] + ruler

    static let schematicTools: [CanvasTool] = cursor + ruler

    static func layoutTools(traceEngine: TraceEngine) -> [CanvasTool] {
        cursor + [TraceTool(traceEngine: traceEngine)] + graphicsTools + ruler
    }
}
