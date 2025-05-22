//
//  SymbolDesignToolbarView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/19/25.
//
import SwiftUI

struct SymbolDesignToolbarView: View {
    @Environment(\.componentDesignManager)
    private var componentDesignManager

    var body: some View {
        ToolbarView<AnyCanvasTool>(
            tools: CanvasToolRegistry.symbolDesignTools,
            dividerBefore: { tool in
                tool.id == "ruler"
            },
            dividerAfter: { tool in
                tool.id == "cursor" || tool.id == "circle"
            },
            imageName: { $0.symbolName },
            onToolSelected: { tool in
                componentDesignManager.selectedSymbolTool = tool
            }
        )
    }
}
