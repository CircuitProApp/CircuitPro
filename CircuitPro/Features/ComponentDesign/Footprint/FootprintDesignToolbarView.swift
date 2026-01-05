//
//  FootprintDesignToolbarView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 5/7/25.
//

import SwiftUI

struct FootprintDesignToolbarView: View {

    @BindableEnvironment(CanvasEditorManager.self)
    private var footprintEditor

    var body: some View {
        CanvasToolbarView(
            selectedTool: $footprintEditor.selectedTool.unwrapping(withDefault: CursorTool())
        ) {
            CursorTool()
            CanvasToolbarDivider()
            LineTool()
            RectangleTool()
            CircleTool()
            CanvasToolbarDivider()
            PadTool()
        }
    }
}
