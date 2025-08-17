//
//  LibraryModeView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/18/25.
//

import SwiftUI

enum LibraryMode: Displayable {
    case all
    case user
    case packs
    
    var label: String {
        switch self {
        case .all:
            return "All"
        case .user:
            return "User"
        case .packs:
            return "Packs"
        }
    }
    
    var icon: String {
        switch self {
        case .all:
            return "list.bullet"
        case .user:
            return "person"
        case .packs:
            return "shippingbox"
        }
    }
}

struct LibraryModeView: View {
    @Binding var selectedMode: LibraryMode
    var body: some View {
        HStack(spacing: 15) {
            ForEach(LibraryMode.allCases) { mode in
                Button {
                    selectedMode = mode
                } label: {
                    Image(systemName: mode.icon)
                        .font(.title3)
                        .scaledToFit()
                        .foregroundStyle(selectedMode == mode ? .blue : .secondary)
                        .symbolVariant(selectedMode == mode ? .fill : .none)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(7.5)
    }
}
