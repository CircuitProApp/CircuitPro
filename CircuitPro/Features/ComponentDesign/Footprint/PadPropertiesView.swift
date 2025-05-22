//
//  PadPropertiesView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 5/7/25.
//

import SwiftUI

struct PadPropertiesView: View {

    @Binding var pad: Pad

    var body: some View {
        Group {
            IntegerField(title: "Number", value: $pad.number)

            Picker("Pad Type", selection: $pad.type) {
                ForEach(PadType.allCases) { padType in
                    Text(padType.label).tag(padType)
                }
            }

            if pad.type == .throughHole {
                fieldWithUnit {
                    DoubleField(
                        title: "Drill Diameter",
                        value: Binding(
                            get: { pad.drillDiameter ?? 0.0 },
                            set: { pad.drillDiameter = $0 }
                        ),
                        displayMultiplier: 0.1
                    )
                }
            }

            Picker("Shape", selection: Binding(
                get: { pad.isCircle ? "Circle" : "Rectangle" },
                set: { pad.shape = $0 == "Circle" ? .circle(radius: 5) : .rect(width: 5, height: 10) }
            )) {
                Text("Circle").tag("Circle")
                Text("Rectangle").tag("Rectangle")
            }

            if pad.isCircle {
                fieldWithUnit {
                    DoubleField(title: "Radius", value: $pad.radius, displayMultiplier: 0.1)
                }
            } else {
                fieldWithUnit {
                    DoubleField(title: "Width", value: $pad.width, displayMultiplier: 0.1)
                }
                fieldWithUnit {
                    DoubleField(title: "Height", value: $pad.height, displayMultiplier: 0.1)
                }
            }
        }
    }

    /// Generic wrapper for unit-labeled numeric fields
    private func fieldWithUnit(@ViewBuilder content: () -> some View) -> some View {
        HStack(alignment: .bottom, spacing: 2) {
            content()
            Text("mm")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
