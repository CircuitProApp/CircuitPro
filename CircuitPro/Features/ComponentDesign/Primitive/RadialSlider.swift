//
//  RadialSlider.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/29/25.
//

import SwiftUI
import AppKit

public struct RadialSlider<T: BinaryFloatingPoint>: NSViewRepresentable {
    // MARK: - Public API
    @Binding public var value: T
    public var range: ClosedRange<T> = 0...360
    public var isContinuous: Bool = true
    public var tickCount: Int? = nil
    public var tickStepDegrees: T? = nil
    public var snapsToTicks: Bool = false
    public var isEnabled: Bool = true
    public var altIncrementValue: T? = nil

    public init(
        value: Binding<T>,
        range: ClosedRange<T>,
        isContinuous: Bool = true,
        tickCount: Int? = nil,
        tickStepDegrees: T? = nil,
        snapsToTicks: Bool = false,
        isEnabled: Bool = true,
        altIncrementValue: T? = nil
    ) {
        self._value = value
        self.range = range
        self.isContinuous = isContinuous
        self.tickCount = tickCount
        self.tickStepDegrees = tickStepDegrees
        self.snapsToTicks = snapsToTicks
        self.isEnabled = isEnabled
        self.altIncrementValue = altIncrementValue
    }

    // MARK: - NSViewRepresentable
    public func makeNSView(context: Context) -> NSSlider {
        let slider = NSSlider()
        if let cell = slider.cell as? NSSliderCell {
            cell.sliderType = .circular
        }

        slider.minValue = Double(range.lowerBound)
        slider.maxValue = Double(range.upperBound)
        slider.doubleValue = Double(value)
        
        slider.isContinuous = isContinuous
        slider.isEnabled = isEnabled
        // 1. We will NOT set allowsTickMarkValuesOnly. We handle snapping ourselves.
        slider.numberOfTickMarks = computedTickCount()

        if let alt = altIncrementValue {
            slider.altIncrementValue = Double(alt)
        }

        slider.target = context.coordinator
        slider.action = #selector(Coordinator.changed(_:))
        return slider
    }

    public func updateNSView(_ slider: NSSlider, context: Context) {
        if let cell = slider.cell as? NSSliderCell, cell.sliderType != .circular {
            cell.sliderType = .circular
        }

        slider.isContinuous = isContinuous
        slider.isEnabled = isEnabled

        if slider.minValue != Double(range.lowerBound) { slider.minValue = Double(range.lowerBound) }
        if slider.maxValue != Double(range.upperBound) { slider.maxValue = Double(range.upperBound) }
        
        let ticks = computedTickCount()
        if slider.numberOfTickMarks != ticks { slider.numberOfTickMarks = ticks }

        if abs(slider.doubleValue - Double(value)) > 0.0001 {
             slider.doubleValue = Double(value)
        }

        if let alt = altIncrementValue {
             slider.altIncrementValue = Double(alt)
        }
    }

    public func makeCoordinator() -> Coordinator { Coordinator(self) }

    public final class Coordinator: NSObject {
        var parent: RadialSlider
        init(_ parent: RadialSlider) { self.parent = parent }
        
        // 2. This is the new, robust snapping logic
        @objc func changed(_ sender: NSSlider) {
            var rawValue = sender.doubleValue
            
            // If snapping is enabled, calculate the snapped value ourselves
            if parent.snapsToTicks, let step = parent.tickStepDegrees, step > 0 {
                let stepAsDouble = Double(step)
                
                // Calculate how many steps fit into the current value from the slider
                let numSteps = (rawValue / stepAsDouble).rounded()
                
                // The new value is simply the number of steps multiplied by the step value
                let snappedValue = numSteps * stepAsDouble
                
                // Clamp the snapped value to the slider's range to avoid over/undershooting at the ends
                let clampedValue = max(Double(parent.range.lowerBound), min(snappedValue, Double(parent.range.upperBound)))
                
                // If the slider isn't already at the clamped value, set it.
                // This provides correct visual feedback to the user.
                if abs(sender.doubleValue - clampedValue) > 0.0001 {
                    sender.doubleValue = clampedValue
                }
                rawValue = clampedValue
            }
            
            // Update the binding with the (potentially snapped) value
            parent.value = T(rawValue)
        }
    }

    // MARK: - Helpers
    private func computedTickCount() -> Int {
        if let step = tickStepDegrees, step > 0 {
            let span = range.upperBound - range.lowerBound
            let segments = max(0, Int((Double(span) / Double(step)).rounded(.towardZero)))
            return segments + 1
        }
        return max(0, tickCount ?? 0)
    }
}
