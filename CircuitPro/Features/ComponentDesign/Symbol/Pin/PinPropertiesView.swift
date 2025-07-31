//
//  PinPropertiesView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 5/2/25.
//
import SwiftUI

struct PinPropertiesView: View {

    @Binding var pin: Pin

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            
            // 1. Identity and Type Section
            InspectorSection(title: "Identity and Type") {
                // The Grid handles the two-column layout for this section.
            
                    InspectorRow(title: "Name") {
                        TextField("e.g. SDA", text: $pin.name)
                            .inspectorField()
                    }
                    InspectorRow(title: "Number") {
                        InspectorNumericField(title: "Number", value: $pin.number, titleDisplayMode: .hidden)
                    }

                    InspectorRow(title: "Function") {
                        Picker("Function", selection: $pin.type) {
                            ForEach(PinType.allCases) { pinType in
                                Text(pinType.label).tag(pinType)
                            }
                        }
                        .labelsHidden()
                        .controlSize(.small)
                    }
                
            }
            Divider()

            // 2. Display Section
            InspectorSection(title: "Display") {
               
                InspectorRow(title: "Length") {
                    Picker("Length", selection: $pin.lengthType) {
                        ForEach(PinLengthType.allCases) { pinLengthType in
                            Text(pinLengthType.label).tag(pinLengthType)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                }
       
                GridRow {
                    // This control spans both columns and is placed on its own row.
                    Toggle("Show Name", isOn: $pin.showLabel)
                        .gridCellColumns(2)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .disabled(pin.name.isEmpty)
                }
                
                GridRow {
                    Toggle("Show Number", isOn: $pin.showNumber)
                        .gridCellColumns(2)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                
            }
            Divider()
            PointControlView(title: "Position", point: $pin.position, displayOffset: PaperSize.component.centerOffset())
            Divider()
            RotationControlView(object: $pin, tickCount: 3, tickStepDegrees: 90, snapsToTicks: true)
        }
        .padding(10)
    }
}
