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
            InspectorSection("Identity and Type") {
                // The Grid handles the two-column layout for this section.
            
                    InspectorRow("Name") {
                        TextField("e.g. SDA", text: $pin.name)
                            .inspectorField()
                    }
                    InspectorRow("Number") {
                        HStack(spacing: 0) {
                            InspectorNumericField(title: "Number", value: $pin.number, titleDisplayMode: .hidden)
                            Color.clear
                        }
                    }

                    InspectorRow("Function") {
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
            InspectorSection("Transform") {
                PointControlView(title: "Position", point: $pin.position, displayOffset: PaperSize.component.centerOffset())
       
                RotationControlView(object: $pin, tickStepDegrees: 90)
            }

            Divider()

            // 2. Display Section
            InspectorSection( "Display") {
               
                InspectorRow("Length") {
                    Picker("Length", selection: $pin.lengthType) {
                        ForEach(PinLengthType.allCases) { pinLengthType in
                            Text(pinLengthType.label).tag(pinLengthType)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                }
       
                InspectorRow("Name") {
                    // This control spans both columns and is placed on its own row.
                    Toggle("Show Name", isOn: $pin.showLabel)
                        .labelsHidden()
                        .disabled(pin.name.isEmpty)
                }
                
                InspectorRow("Number") {
                    Toggle("Show Number", isOn: $pin.showNumber)
                        .labelsHidden()
                }

                
            }

        }
        .padding(10)
    }
}
