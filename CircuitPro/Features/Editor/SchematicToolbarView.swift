//
//  SchematicToolbarView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 19.06.25.
//

import SwiftUI

struct SchematicToolbarView: View {
    @Binding var selectedSchematicTool: CanvasTool

    var body: some View {
        CanvasToolbarView(
            selectedTool: $selectedSchematicTool.unwrapping(withDefault: CursorTool())
        ) {
            CursorTool()
        }
    }
}
