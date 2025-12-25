//
//  DesignNavigatorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 09.06.25.
//

import SwiftUI

public struct DesignNavigatorView: View {
    @BindableEnvironment(\.projectManager)
    private var projectManager

    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: CircuitProSymbols.Design.design)
            Text(projectManager.selectedDesign.name)
                .font(.system(size: 11))
                .fontWeight(.semibold)
            Spacer()
        }
        .foregroundStyle(.secondary)
    }
}
