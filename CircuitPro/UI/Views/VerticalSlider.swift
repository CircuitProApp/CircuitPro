//
//  VerticalSlider.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/14/25.
//

import SwiftUI

struct VerticalSlider: NSViewRepresentable {
    @Binding var value: Double
    var bounds: ClosedRange<Double>
    var tickMarks: Int = 5
    var onlyAllowTickValues: Bool = false

    class Coordinator: NSObject {
        var value: Binding<Double>

        init(value: Binding<Double>) {
            self.value = value
        }

        @objc
        func valueChanged(_ sender: NSSlider) {
            self.value.wrappedValue = sender.doubleValue
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value)
    }

    func makeNSView(context: Context) -> NSSlider {
        let slider = NSSlider()
        slider.isVertical = true
        slider.minValue = bounds.lowerBound
        slider.maxValue = bounds.upperBound
        slider.doubleValue = value

        slider.numberOfTickMarks = tickMarks
        slider.allowsTickMarkValuesOnly = onlyAllowTickValues
        slider.tickMarkPosition = .leading // Could also be `.trailing`

        slider.target = context.coordinator
        slider.action = #selector(Coordinator.valueChanged(_:))
        return slider
    }

    func updateNSView(_ nsView: NSSlider, context: Context) {
        nsView.doubleValue = value
        nsView.minValue = bounds.lowerBound
        nsView.maxValue = bounds.upperBound
        nsView.numberOfTickMarks = tickMarks
        nsView.allowsTickMarkValuesOnly = onlyAllowTickValues
    }
}
