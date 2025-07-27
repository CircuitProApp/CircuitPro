//
//  PositionEditor.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/27/25.
//

import SwiftUI

struct PositionEditor: View {
    let label: String
    @Binding var position: CGPoint

    var body: some View {
        HStack {
            Text(label)
            // x field
            DoubleField(title: "x", value: Binding<Double>(
                get: { Double(position.x) },
                set: { newValue in
                    position.x = CGFloat(newValue)
                }
            ))
            // y field
            DoubleField(title: "y", value: Binding<Double>(
                get: { Double(position.y) },
                set: { newValue in
                    position.y = CGFloat(newValue)
                }
            ))
        }
    }
}

