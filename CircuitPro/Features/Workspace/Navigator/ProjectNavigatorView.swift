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
    
    var document: CircuitProjectDocument
    
    var body: some View {
        @Bindable var bindableProjectManager = projectManager
        
        Group {
            DesignNavigatorView(document: document)

            Divider().foregroundStyle(.quaternary)
            
            SymbolNavigatorView()

            
        }
    }
}
