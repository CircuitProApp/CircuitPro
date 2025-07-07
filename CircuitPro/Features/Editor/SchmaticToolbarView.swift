//
//  SchematicToolbarView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 19.06.25.
//

import SwiftUI

struct SchematicToolbarView: View {
    @Binding var selectedSchematicTool: AnyCanvasTool

    var body: some View {
        ToolbarView<AnyCanvasTool>(
            tools: CanvasToolRegistry.schematicTools,
            dividerBefore: { tool in
                tool.id == "ruler"
            },
            dividerAfter: { tool in
                tool.id == "cursor"
            },
            imageName: { $0.symbolName },
            onToolSelected: { tool in
                selectedSchematicTool = tool
            }
        )
    }
}
