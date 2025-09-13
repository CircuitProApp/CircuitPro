//
//  FootprintDesignToolbarView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 5/7/25.
//

import SwiftUI

struct FootprintDesignToolbarView: View {
    // Just like the Canvas and Properties views, the toolbar now sources
    // the active editor directly from the environment.
    @Environment(CanvasEditorManager.self) private var footprintEditor

    var body: some View {
        // Bind to the environment's editor instance.
        @Bindable var manager = footprintEditor
        
        CanvasToolbarView(
            tools: CanvasToolRegistry.footprintDesignTools,
            // The `selectedTool` property is non-optional, so we can bind to it directly.
            selectedTool: $manager.selectedTool.unwrapping(withDefault: CursorTool()),
            dividerBefore: { $0 is PadTool },
            dividerAfter: { $0 is CursorTool }
      
        )
    }
}
