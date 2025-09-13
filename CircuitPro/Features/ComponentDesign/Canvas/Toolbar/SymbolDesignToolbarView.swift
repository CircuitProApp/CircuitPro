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
            tools: CanvasToolRegistry.symbolDesignTools,
            selectedTool: $symbolEditor.selectedTool.unwrapping(withDefault: CursorTool()),
            dividerBefore: { $0 is PinTool },
            dividerAfter: { $0 is CursorTool }
        )
    }
}
