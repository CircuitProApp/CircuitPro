//
//  SymbolDesignToolbarView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/19/25.
//
import SwiftUI

struct SymbolDesignToolbarView: View {
    @Environment(ComponentDesignManager.self) private var componentDesignManager

    var body: some View {
        @Bindable var manager = componentDesignManager.symbolEditor
        ToolbarView<AnyCanvasTool>(
            tools: CanvasToolRegistry.symbolDesignTools,
            selectedTool: $manager.selectedTool,
            dividerBefore: { tool in
                tool.id == "ruler"
            },
            dividerAfter: { tool in
                tool.id == "cursor" || tool.id == "circle"
            },
            imageName: { $0.symbolName }
        )
    }
}
