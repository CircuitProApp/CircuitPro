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
    
    @State private var schematicNavigatorView: SchematicNavigatorType = .symbols
    
    enum SchematicNavigatorType: Displayable {
        case symbols
        case connections
        
        var label: String {
            switch self {
            case .symbols:
                return "Symbols"
            case .connections:
                return "Connections"
            }
        }
    }

    var body: some View {
        @Bindable var bindableProjectManager = projectManager

        Group {
            DesignNavigatorView(document: document)

            Divider().foregroundStyle(.quaternary)

            VStack(spacing: 0) {
                HStack(spacing: 2.5) {
                    Button {
                        schematicNavigatorView = .symbols
                    } label: {
                        Text("Symbols")
                    }
                    .buttonStyle(.plain)
                    .directionalPadding(vertical: 2.5, horizontal: 7.5)
                    .background(schematicNavigatorView == .symbols ? .blue : .clear)
                    .foregroundStyle(schematicNavigatorView == .symbols ? .white : .secondary)
                    .clipShape(.rect(cornerRadius: 5))
                    
                    Button {
                        schematicNavigatorView = .connections
                    } label: {
                        Text("Connections")
                    }
                    .buttonStyle(.plain)
                    .directionalPadding(vertical: 2.5, horizontal: 7.5)
                    .background(schematicNavigatorView == .connections ? .blue : .clear)
                    .foregroundStyle(schematicNavigatorView == .connections ? .white : .secondary)
                    .clipShape(.rect(cornerRadius: 5))
                }
                .frame(height: 28)
                .font(.callout)
                Divider().foregroundStyle(.quinary)
                switch schematicNavigatorView {
                case .symbols:
                    SymbolNavigatorView(document: document)
                case .connections:
                    ConnectionNavigatorView(document: document)
                }
            }
        }
    }
}
