//
//  LayoutToolbarView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/15/25.
//

import SwiftUI

struct LayoutToolbarView: View {
    @Binding var selectedSchematicTool: CanvasTool
    let traceEngine: TraceEngine

    var body: some View {
        CanvasToolbarView(
            tools: CanvasToolRegistry.layoutTools(traceEngine: traceEngine),
            selectedTool: $selectedSchematicTool.unwrapping(withDefault: CursorTool()),
            dividerAfter: { $0 is CursorTool || $0 is TraceTool }
        )
    }
}
