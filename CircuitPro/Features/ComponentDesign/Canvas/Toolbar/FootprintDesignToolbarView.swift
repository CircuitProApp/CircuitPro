//
//  FootprintDesignToolbarView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 5/7/25.
//

import SwiftUI

struct FootprintDesignToolbarView: View {
    @Environment(ComponentDesignManager.self) private var componentDesignManager

    var body: some View {
        @Bindable var manager = componentDesignManager.footprintEditor
        CanvasToolbarView(
            tools: CanvasToolRegistry.footprintDesignTools,
            selectedTool: $manager.selectedTool.unwrapping(withDefault: CursorTool()),
            dividerBefore: { $0 is PadTool },
            dividerAfter: { $0 is CursorTool }
      
        )
    }
}
