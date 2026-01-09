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
    
    var iconName: String {
        switch self {
        case .all:
            return "list.bullet"
        case .user:
            return "person"
        case .packs:
            return "shippingbox"
        }
    }
    
    var searchPlaceholder: String {
        switch self {
        case .all:
            return "All Components"
        case .user:
            return "User Components"
        case .packs:
            return "Packs"
        }
    }
}

struct LibraryModeView: View {
    @Binding var selectedMode: LibraryMode
    var body: some View {
        HStack(spacing: 4) {
            ForEach(LibraryMode.allCases) { mode in
                Button {
                    selectedMode = mode
                } label: {
                    Image(systemName: mode.iconName)
                        .font(.title3)
                        .frame(width: 32, height: 32)
                        .contentShape(.rect())
                        .foregroundStyle(selectedMode == mode ? .blue : .secondary)
                        .symbolVariant(selectedMode == mode ? .fill : .none)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
