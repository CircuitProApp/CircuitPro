//
//  InspectorRow.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/30/25.
//

import SwiftUI

/// A view that represents a single row in an inspector, with a title and a control.
/// This view is designed to be used inside a SwiftUI `Grid`.
struct InspectorRow<Content: View>: View {
    
    @Environment(\.inspectorLabelColumnWidth)
    private var labelColumnWidth
    
    var title: String?
    var style: InspectorRowStyle
    var content: () -> Content
    
    init(_ title: String? = nil, style: InspectorRowStyle = .full, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.style = style
        self.content = content
    }
    
    var body: some View {
        GridRow {
            // Label Column
            Group {
                if let title {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                } else {
                    Color.clear
                }
            }
            .frame(width: labelColumnWidth, alignment: .trailing)
            .gridColumnAlignment(.trailing)
            
            // Content Column
            HStack(spacing: 6) {
                switch style {
                case .full:
                    content()
                case .leading:
                    content()
                    Color.clear
                case .trailing:
                    Color.clear
                    content()
                }
            }
        }
    }
}
