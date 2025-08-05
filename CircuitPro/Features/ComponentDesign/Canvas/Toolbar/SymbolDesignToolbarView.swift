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
        ToolbarView(
            tools: CanvasToolRegistry.symbolDesignTools,
            selectedTool: $manager.selectedTool.unwrapping(withDefault: CursorTool()),
            dividerBefore: { $0 is PinTool },
            dividerAfter: { $0 is CursorTool }
        )
    }
}
