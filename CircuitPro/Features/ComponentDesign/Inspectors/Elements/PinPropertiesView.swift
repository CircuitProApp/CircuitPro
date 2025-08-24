//
//  PinPropertiesView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 5/2/25.
//
import SwiftUI

struct PinPropertiesView: View {

    @Binding var pin: Pin

    private var allLengthTypes: [PinLengthType] { PinLengthType.allCases }

    private var lengthIndex: Binding<Double> {
        Binding<Double>(
            get: { Double(allLengthTypes.firstIndex(of: pin.lengthType) ?? 2) },
            set: {
                let index = Int(round($0))
                if allLengthTypes.indices.contains(index) {
                    pin.lengthType = allLengthTypes[index]
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Pin Properties")
                .font(.title3.weight(.semibold))
            
            InspectorSection("Identity and Type") {
                    InspectorRow("Name") {
                        TextField("e.g. SDA", text: $pin.name)
                            .inspectorField()
                    }

                InspectorRow("Number", style: .leading) {
                   
                        InspectorNumericField(value: $pin.number)
                         
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
                RotationControlView(object: $pin, tickStepDegrees: 90, snapsToTicks: true)
            }

            Divider()

            InspectorSection( "Display") {
                InspectorRow("Length") {
                    Slider(
                        value: lengthIndex,
                        in: 0...Double(allLengthTypes.count - 1),
                        step: 1
                    )
                    .controlSize(.small)
                }
       
                InspectorRow("Name") {
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
