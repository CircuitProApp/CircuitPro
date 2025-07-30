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
        VStack(alignment: .trailing) {
            Text("Pin Properties")
                .font(.title3.weight(.semibold))
            InspectorTextField(title: "Name", text: $pin.name)
            if pin.name.isNotEmpty {
                Toggle("Show Name", isOn: $pin.showLabel)
            }

            InspectorNumericField(title: "Number", value: $pin.number, titleDisplayMode: .label)
                .environment(\.inspectorFieldWidth, 80)
            RotationControlView(object: $pin, tickCount: 3, tickStepDegrees: 90, snapsToTicks: true)

            Toggle("Show Number", isOn: $pin.showNumber)

            Picker("Function", selection: $pin.type) {
                ForEach(PinType.allCases) { pinType in
                    Text(pinType.label).tag(pinType)
                }
            }
            Picker("Length", selection: $pin.lengthType) {
                ForEach(PinLengthType.allCases) { pinLengthType in
                    Text(pinLengthType.label).tag(pinLengthType)
                }
            }
        }
        .padding()
    }
}
