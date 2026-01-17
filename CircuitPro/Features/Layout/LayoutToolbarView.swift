//
//  LayoutToolbarView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/15/25.
//

import SwiftUI

struct LayoutToolbarView: View {
    @Binding var selectedLayoutTool: CanvasTool
    let traceEngine: TraceEngine

    var body: some View {
        CanvasToolbarView(
            selectedTool: $selectedLayoutTool.unwrapping(withDefault: CursorTool())
        ) {
            CursorTool()
            CanvasToolbarDivider()
            TraceTool(traceEngine: traceEngine)
            CanvasToolbarDivider()
            LineTool()
            RectangleTool()
            CircleTool()
        }
    }
}
