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

    // The logic for combining toolsets remains the same, as they are all `[CanvasTool]`.
    static let symbolDesignTools: [CanvasTool] =
        cursor + graphicsTools + [PinTool()] + ruler + text

    static let footprintDesignTools: [CanvasTool] =
        cursor + graphicsTools + [PadTool()] + ruler

    static let schematicTools: [CanvasTool] =
        cursor + /*[ConnectionTool()] +*/ ruler

}
