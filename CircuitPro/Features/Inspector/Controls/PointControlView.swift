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
          
                InspectorNumericField(
                    label: "X",
                    value: $point.x,
                    displayOffset: displayOffset.x,
                    unit: "mm"
                )
                InspectorNumericField(
                    label: "Y",
                    value: $point.y,
                    displayOffset: displayOffset.y,
                    unit: "mm"
                )
            
            
        }
    }
}
