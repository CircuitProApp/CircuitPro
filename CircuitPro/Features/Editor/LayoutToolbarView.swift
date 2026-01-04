//
//  LayoutToolbarView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/15/25.
//

import SwiftUI

struct LayoutToolbarView: View {
    @Binding var selectedSchematicTool: CanvasTool

    var body: some View {
        CanvasToolbarView(
            selectedTool: $selectedSchematicTool.unwrapping(withDefault: CursorTool())
        ) {
            CursorTool()
            CanvasToolbarDivider()
            LineTool()
            RectangleTool()
            CircleTool()
        }
    }
}
