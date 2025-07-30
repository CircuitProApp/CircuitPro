//
//  RadialSlider.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/29/25.
//

import SwiftUI
import AppKit

struct RadialSlider<T: NumericType>: NSViewRepresentable {
    
    // MARK: - ZeroAngle Enum
    public enum ZeroAngle {
        /// 0 degrees is at the 12 o'clock position, increasing clockwise. (NSSlider's native behavior)
        case north
        /// 0 degrees is at the 3 o'clock position, increasing counter-clockwise. (Standard Cartesian)
        case east
    }

    // MARK: - Public API
    @Binding public var value: T
    public var range: ClosedRange<T>
    public var zeroAngle: ZeroAngle
    public var isContinuous: Bool
    public var tickCount: Int?
    public var tickStepDegrees: T?
    public var snapsToTicks: Bool
    public var isEnabled: Bool
    public var altIncrementValue: T?

    public init(
        value: Binding<T>,
        range: ClosedRange<T>,
        zeroAngle: ZeroAngle = .north,
        isContinuous: Bool = true,
        tickCount: Int? = nil,
        tickStepDegrees: T? = nil,
        snapsToTicks: Bool = false,
        isEnabled: Bool = true,
        altIncrementValue: T? = nil
    ) {
        self._value = value
        self.range = range
        self.zeroAngle = zeroAngle
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

        slider.minValue = range.lowerBound.doubleValue
        slider.maxValue = range.upperBound.doubleValue
        slider.doubleValue = context.coordinator.toSliderValue(value.doubleValue)

        slider.isContinuous = isContinuous
        slider.isEnabled = isEnabled
        slider.numberOfTickMarks = computedTickCount()

        if let alt = altIncrementValue {
            slider.altIncrementValue = alt.doubleValue
        }

        slider.target = context.coordinator
        slider.action = #selector(Coordinator.changed(_:))
        return slider
    }

    public func updateNSView(_ nsView: NSSlider, context: Context) {
        if let cell = nsView.cell as? NSSliderCell, cell.sliderType != .circular {
            cell.sliderType = .circular
        }

        nsView.isContinuous = isContinuous
        nsView.isEnabled = isEnabled

        if nsView.minValue != range.lowerBound.doubleValue { nsView.minValue = range.lowerBound.doubleValue }
        if nsView.maxValue != range.upperBound.doubleValue { nsView.maxValue = range.upperBound.doubleValue }

        let ticks = computedTickCount()
        if nsView.numberOfTickMarks != ticks { nsView.numberOfTickMarks = ticks }

        let modelValue = value.doubleValue
        let sliderValue = context.coordinator.toSliderValue(modelValue)
        if abs(nsView.doubleValue - sliderValue) > 0.0001 {
             nsView.doubleValue = sliderValue
        }

        if let alt = altIncrementValue {
             nsView.altIncrementValue = alt.doubleValue
        }
    }

    public func makeCoordinator() -> Coordinator { Coordinator(self) }

    public final class Coordinator: NSObject {
        var parent: RadialSlider
        init(_ parent: RadialSlider) { self.parent = parent }

        @objc func changed(_ sender: NSSlider) {
            let sliderValue = sender.doubleValue
            var modelValue = self.toModelValue(sliderValue)

            if parent.snapsToTicks, let step = parent.tickStepDegrees?.doubleValue, step > 0 {
                let numSteps = (modelValue / step).rounded()
                let snappedValue = numSteps * step
                let clampedValue = max(parent.range.lowerBound.doubleValue, min(snappedValue, parent.range.upperBound.doubleValue))
                
                let newSliderValue = self.toSliderValue(clampedValue)
                if abs(sender.doubleValue - newSliderValue) > 0.0001 {
                    sender.doubleValue = newSliderValue
                }
                modelValue = clampedValue
            }

            parent.value = T(modelValue)
        }
        
        // MARK: - Coordinate Conversion
        private func normalize(_ angle: Double) -> Double {
            let result = angle.truncatingRemainder(dividingBy: 360)
            return result < 0 ? result + 360 : result
        }

        /// Converts a value from the parent's coordinate system to the NSSlider's native system.
        func toSliderValue(_ modelValue: Double) -> Double {
            switch parent.zeroAngle {
            case .north:
                // Model and slider coordinate systems match, no conversion needed.
                return modelValue
            case .east:
                // Convert from Model(0°=E, CCW) to Slider(0°=N, CW)
                return normalize(-modelValue + 90)
            }
        }

        /// Converts a value from the NSSlider's native coordinate system to the parent's system.
        func toModelValue(_ sliderValue: Double) -> Double {
            switch parent.zeroAngle {
            case .north:
                // Model and slider coordinate systems match, no conversion needed.
                return sliderValue
            case .east:
                // Convert from Slider(0°=N, CW) to Model(0°=E, CCW)
                return normalize(-sliderValue + 90)
            }
        }
    }

    // MARK: - Helpers
    private func computedTickCount() -> Int {
        if let step = tickStepDegrees, step > (0 as T) {
            let span = range.upperBound - range.lowerBound
            let segments = max(0, Int((span.doubleValue / step.doubleValue).rounded(.towardZero)))
            return segments + 1
        }
        return max(0, tickCount ?? 0)
    }
}
