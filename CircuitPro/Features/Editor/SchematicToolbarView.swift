//
//  SchematicToolbarView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 19.06.25.
//

import SwiftUI

struct SchematicToolbarView: View {
    @Binding var selectedSchematicTool: CanvasTool
    let wireEngine: WireEngine

    var body: some View {
        CanvasToolbarView(
            tools: CanvasToolRegistry.schematicTools(wireEngine: wireEngine),
            selectedTool: $selectedSchematicTool.unwrapping(withDefault: CursorTool()),
            dividerAfter: { $0 is CursorTool }
        )
    }
}
