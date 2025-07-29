//
//  InspectorSection.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/30/25.
//

import SwiftUI

/// A reusable layout for inspector controls with a title and trailing content.
struct InspectorSection<Content: View>: View {
    var title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
            }
            HStack {
                Spacer()
                content()
            }
        }
    }
}
