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
        Group {
            TextField("Name", text: $pin.name, prompt: Text("e.g SCL"))
            if pin.name.isNotEmpty {
                Toggle("Show Name", isOn: $pin.showLabel)
            }

            IntegerField(title: "Number", value: $pin.number)

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
    }
}
