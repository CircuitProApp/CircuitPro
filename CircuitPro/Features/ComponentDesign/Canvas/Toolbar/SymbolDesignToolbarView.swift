//
//  SymbolDesignToolbarView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/19/25.
//

import SwiftUI

struct SymbolDesignToolbarView: View {
    @BindableEnvironment(CanvasEditorManager.self)
    private var symbolEditor

    var body: some View {
        CanvasToolbarView(
            selectedTool: $symbolEditor.selectedTool.unwrapping(withDefault: CursorTool())
        ) {
            CursorTool()
            CanvasToolbarDivider()
            LineTool()
            RectangleTool()
            CircleTool()
            CanvasToolbarDivider()
            PinTool()
        }
    }
}
