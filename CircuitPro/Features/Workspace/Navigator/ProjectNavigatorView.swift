//
//  ProjectNavigatorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 01.06.25.
//

import SwiftUI

struct ProjectNavigatorView: View {

    @Environment(\.projectManager)
    private var projectManager

    var document: CircuitProjectFileDocument
    
    var body: some View {
        VStack(spacing: 0) {
            DesignNavigatorView(document: document)

            Divider().foregroundStyle(.quaternary)
            switch projectManager.selectedEditor {
            case .schematic:
                SchematicNavigatorView(document: document)
            case .layout:
                LayoutNavigatorView(document: document)
            }
        }
    }
}
