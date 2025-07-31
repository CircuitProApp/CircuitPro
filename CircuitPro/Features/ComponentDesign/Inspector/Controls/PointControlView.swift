//
//  PointControlView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/29/25.
//

import SwiftUI

/// A reusable control for editing the X and Y values of any CGPoint binding.
struct PointControlView: View {
    var title: String
    @Binding var point: CGPoint
    var displayOffset: CGPoint = .zero

    var body: some View {

        InspectorRow(title) {
            HStack(spacing: 4) {
                InspectorNumericField(
                    title: "X",
                    value: $point.x,
                    displayOffset: displayOffset.x
                )
                InspectorNumericField(
                    title: "Y",
                    value: $point.y,
                    displayOffset: displayOffset.y
                )
            }
            
        }
    }
}
