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

    var title: String?
    var content: () -> Content
    
    init(_ title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        GridRow {
            Group {
                if let title {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Color.clear
                }
            }
            .frame(width: 70, alignment: .trailing)
            .gridColumnAlignment(.trailing)
            
            HStack(spacing: 6) {
                content()
            }
        }
    }
}
