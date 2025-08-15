//
//  CollapsePaneButton.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/15/25.
//

import SwiftUI

struct CollapsePaneButton: View {
    
    @Binding var isCollapsed: Bool
    
    var body: some View {
        Button {
            self.isCollapsed.toggle()
        } label: {
            Image(systemName: CircuitProSymbols.Workspace.toggleUtilityArea)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 13, height: 13)
                .fontWeight(.light)
        }
        .buttonStyle(.borderless)
    }
}
