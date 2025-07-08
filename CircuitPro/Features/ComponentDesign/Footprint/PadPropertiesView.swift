//
//  PadPropertiesView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 5/7/25.
//

import SwiftUI

struct PadPropertiesView: View {

    @State private var showDrillDialog: Bool = false

    @Binding var pad: Pad
    
    var isTooLarge: Bool {
        let drill = pad.drillDiameter ?? 0.0
        return pad.isCircle
            ? drill > pad.radius
            : drill > pad.width || drill > pad.height
    }

    var body: some View {
        Group {
            IntegerField(title: "Number", value: $pad.number)

            Picker("Pad Type", selection: $pad.type) {
                ForEach(PadType.allCases) { padType in
                    Text(padType.label).tag(padType)
                }
            }

            if pad.type == .throughHole {
                HStack {
                    if isTooLarge {
                        Image(systemName: CircuitProSymbols.Workspace.ruleChecks)
                            .symbolVariant(.fill)
                            .foregroundStyle(.primary, .yellow)
                            .onHover { _ in showDrillDialog.toggle() }
                            .popover(isPresented: $showDrillDialog) {
                                Text("Drill diameter exceeds pad size.")
                                    .padding(7.5)
                            }
                    }
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
                    .foregroundStyle(isTooLarge ? .red : .primary)
                }
                .animation(.default, value: isTooLarge)
           
            }

            Picker("Shape", selection: Binding(
                get: { pad.isCircle ? "Circle" : "Rectangle" },
                set: { pad.shape = $0 == "Circle" ? .circle(radius: 5) : .rect(width: 5, height: 10) }
            )) {
                Text("Circle").tag("Circle")
                Text("Rectangle").tag("Rectangle")
            }

            Group {
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
            .foregroundStyle(isTooLarge ? .red : .primary)
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
