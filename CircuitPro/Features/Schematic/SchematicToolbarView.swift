//
//  SchematicToolbarView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 19.06.25.
//

import SwiftUI

struct SchematicToolbarView: View {
    @Binding var selectedSchematicTool: CanvasTool
    let wireEngine: any ConnectionEngine

    var body: some View {
        CanvasToolbarView(
            selectedTool: $selectedSchematicTool.unwrapping(withDefault: CursorTool())
        ) {
            CursorTool()
            CanvasToolbarDivider()
            WireTool(engine: wireEngine)
        }
    }
}
