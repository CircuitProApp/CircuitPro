//
//  ProjectNavigatorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 01.06.25.
//

import SwiftUI

struct ProjectNavigatorView: View {

    @Environment(\.editorSession)
    private var editorSession

    var body: some View {
        VStack(spacing: 0) {
            switch editorSession.selectedEditor {
            case .schematic:
                SchematicNavigatorView()
            case .layout:
                LayoutNavigatorView()
            }
        }
    }
}
