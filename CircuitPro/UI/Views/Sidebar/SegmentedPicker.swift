//
//  SegmentedPicker.swift
//  CircuitPro
//

import SwiftUI

struct SegmentedPicker<Selection: Hashable>: View {
    let options: [Selection]
    @Binding var selection: Selection
    let label: (Selection) -> String

    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation(.smooth(duration: 0.3)) {
                        selection = option
                    }
                } label: {
                    Text(label(option))
                        .font(.callout.weight(.medium))
                        .foregroundStyle(selection == option ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background {
                            if selection == option {
                                Capsule()
                                    .fill(.blue)
                                    .matchedGeometryEffect(
                                        id: "selection-background",
                                        in: namespace
                                    )
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(.quaternary.opacity(0.6))
        )
        .padding(.horizontal, 8)
    }
}
