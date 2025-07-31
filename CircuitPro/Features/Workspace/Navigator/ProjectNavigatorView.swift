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

    @State private var schematicNavigatorView: SchematicNavigatorType = .symbols
    
    @Namespace private var namespace

    var body: some View {
        @Bindable var bindableProjectManager = projectManager

        Group {
            DesignNavigatorView(document: document)

            Divider().foregroundStyle(.quaternary)

            VStack(spacing: 0) {
                HStack(spacing: 2.5) {
                    ForEach(SchematicNavigatorType.allCases, id: \.self) { tab in
                        Button {
                            withAnimation(.snappy(duration: 0.25)) {
                                schematicNavigatorView = tab
                            }
                        } label: {
                            Text(tab.label)
                                .padding(.vertical, 2.5)
                                .padding(.horizontal, 7.5)
                                .background {
                                    if schematicNavigatorView == tab {
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(.blue)
                                            .matchedGeometryEffect(id: "selection-background", in: namespace)
                                    }
                                }
                                .foregroundStyle(schematicNavigatorView == tab ? .white : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(height: 28)
                .font(.callout)

                Divider().foregroundStyle(.quinary)

                switch schematicNavigatorView {
                case .symbols:
                    SymbolNavigatorView(document: document)
                        .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .leading)))
           
                case .connections:
                    ConnectionNavigatorView(document: document)
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
                }
            }
        }
    }
}
