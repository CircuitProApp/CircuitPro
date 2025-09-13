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
            tools: CanvasToolRegistry.footprintDesignTools,
            selectedTool: $footprintEditor.selectedTool.unwrapping(withDefault: CursorTool()),
            dividerBefore: { $0 is PadTool },
            dividerAfter: { $0 is CursorTool }
        )
    }
}
