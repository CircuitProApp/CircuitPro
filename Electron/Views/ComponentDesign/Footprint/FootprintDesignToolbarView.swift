//
//  FootprintDesignToolbarView.swift
//  Electron
//
//  Created by Giorgi Tchelidze on 5/7/25.
//

import SwiftUI

struct FootprintDesignToolbarView: View {
    @Environment(\.componentDesignManager) private var componentDesignManager

    var body: some View {
        ToolbarView<AnyCanvasTool>(
            tools: CanvasToolRegistry.symbolDesignTools,
            dividerAfter: { tool in
                tool.id == "cursor" || tool.id == "circle"
            },
            imageName: { $0.symbolName },
            onToolSelected: { tool in
                componentDesignManager.selectedFootprintTool = tool
            }
        )
    }
}
