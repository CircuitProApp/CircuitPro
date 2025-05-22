//
//  LayoutToolbarView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/5/25.
//

import SwiftUI

// Define the tools for the layout toolbar.
enum LayoutTool: String, CaseIterable {
    case cursor = "cursorarrow"
    case trace = "line.diagonal.arrow"
    case via = "smallcircle.filled.circle.fill"
    case zone = "inset.filled.square.dashed"
    case line = "line.diagonal"
    case arc = "wave.3.up"
    case rectangle = "rectangle"
    case circle = "circle"
    case polygon = "hexagon"

    // Conform to ToolbarTool by specifying the default cursor.
    static var cursorCase: LayoutTool { .cursor }
}

struct LayoutToolbarView: View {

    var body: some View {
//        ToolbarView<LayoutTool>(
//            tools: LayoutTool.allCases,
//            // Insert a divider after the cursor and zone tools.
//            dividerAfter: { tool in
//                tool == .cursor || tool == .zone
//            },
//            imageName: { $0.rawValue },
//            onToolSelected: { tool in
//                // Handle layout tool selection.
//                print("Layout tool selected:", tool)
//                canvasManager.selectedLayoutTool = tool
//            }
//        )
        Text("Hello, World!")
    }
}

#Preview {
    LayoutToolbarView()
}
