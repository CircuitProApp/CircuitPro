//
//  PointControlView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/29/25.
//

import SwiftUI

/// A reusable control for editing the X and Y values of any CGPoint binding.
struct PointControlView: View {
    var title: String = "Position"
    @Binding var point: CGPoint
    var displayOffset: CGPoint = .zero

    var body: some View {
        VStack(alignment: .leading) {
            Text(title).font(.headline)
            HStack {
                FloatingPointField(
                    title: "x",
                    value: $point.x,
                    displayOffset: displayOffset.x
                )
                FloatingPointField(
                    title: "y",
                    value: $point.y,
                    displayOffset: displayOffset.y
                )
            }
        }
    }
}
