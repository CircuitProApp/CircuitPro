//
//  SchematicToolbar.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/5/25.
//

import SwiftUI

// Define the tools for the schematic toolbar.
enum SchematicTool: String, CaseIterable {
    case cursor = "cursorarrow"
    case wire = "line.diagonal"
    case noconnect = "xmark"

    // Conform to ToolbarTool by specifying the default cursor.
    static var cursorCase: SchematicTool { .cursor }
}

struct SchematicToolbarView: View {

    var body: some View {
//        ToolbarView<SchematicTool>(
//            tools: SchematicTool.allCases,
//            // Insert a divider after the cursor tool.
//            dividerAfter: { tool in
//                tool == .cursor
//            },
//            imageName: { $0.rawValue },
//            onToolSelected: { tool in
//                // Handle schematic tool selection.
//                print("Schematic tool selected:", tool)
//                canvasManager.selectedSchematicTool = tool
//            }
//        )
        Text("Hello, World!")
    }
}

#Preview {
    SchematicToolbarView()
}
