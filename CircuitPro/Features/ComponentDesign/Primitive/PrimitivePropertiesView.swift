//
//  PrimitivePropertiesView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/27/25.
//

import SwiftUI

struct PrimitivePropertiesView: View {
    @Binding var primitive: AnyPrimitive
    
    var body: some View {
        switch primitive {
        case .rectangle:
            if let rectBinding = $primitive.rectangle {
                RectanglePropertiesView(rectangle: rectBinding)
            }
        case .circle:
            if let circBinding = $primitive.circle {
                CirclePropertiesView(circle: circBinding)
            }
        case .line:
            if let lineBinding = $primitive.line {
                LinePropertiesView(line: lineBinding)
            }
        default:
            Text("Unsupported primitive")
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Properties Views for Each Primitive Type

struct RectanglePropertiesView: View {
    @Binding var rectangle: RectanglePrimitive
    
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            InspectorSection(title: "Size") {
                InspectorNumericField(title: "W", value: $rectangle.size.width)
                InspectorNumericField(title: "H", value: $rectangle.size.height)
            }
            Divider()
            PointControlView(
                point: $rectangle.position,
                displayOffset: PaperSize.component.centerOffset()
            )
            Divider()
            RotationControlView(object: $rectangle)
            Divider()
            StrokeAndFillControlView(object: $rectangle)
            Divider()
            InspectorSection(title: "Corner Radius") {
                Slider(value: $rectangle.cornerRadius, in: 0...rectangle.maximumCornerRadius)
                    .labelsHidden()
                InspectorNumericField(
                    title: "",
                    value: $rectangle.cornerRadius,
                    range: 0...rectangle.maximumCornerRadius,
                    maxDecimalPlaces: 1,
                    titleDisplayMode: .label)
            }           
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}

struct CirclePropertiesView: View {
    @Binding var circle: CirclePrimitive
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            InspectorSection(title: "Size") {
                InspectorNumericField(title: "Radius", value: $circle.radius, titleDisplayMode: .label)
            }
            Divider()
            PointControlView(
                point: $circle.position,
                displayOffset: PaperSize.component.centerOffset()
            )
            Divider()
            RotationControlView(object: $circle)
            Divider()
            StrokeAndFillControlView(object: $circle)
            
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}

struct LinePropertiesView: View {
    @Binding var line: LinePrimitive
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            PointControlView(
                title: "Start Point",
                point: $line.start,
                displayOffset: PaperSize.component.centerOffset()
            )
            PointControlView(
                title: "End Point",
                point: $line.end,
                displayOffset: PaperSize.component.centerOffset()
            )
            Divider()
            RotationControlView(object: $line)
            Divider()
            StrokeAndFillControlView(object: $line)
    
        }
        .padding()
    }
}

// Allows creating bindings to the specific values within an enum binding.
extension Binding where Value == AnyPrimitive {
    var rectangle: Binding<RectanglePrimitive>? {
        guard case .rectangle = self.wrappedValue else { return nil }
        return Binding<RectanglePrimitive>(
            get: {
                if case .rectangle(let value) = self.wrappedValue {
                    return value
                } else {
                    fatalError("The primitive is no longer a rectangle.")
                }
            },
            set: { self.wrappedValue = .rectangle($0) }
        )
    }
    
    var circle: Binding<CirclePrimitive>? {
        guard case .circle = self.wrappedValue else { return nil }
        return Binding<CirclePrimitive>(
            get: {
                if case .circle(let value) = self.wrappedValue {
                    return value
                } else {
                    fatalError("The primitive is no longer a circle.")
                }
            },
            set: { self.wrappedValue = .circle($0) }
        )
    }
    
    var line: Binding<LinePrimitive>? {
        guard case .line = self.wrappedValue else { return nil }
        return Binding<LinePrimitive>(
            get: {
                if case .line(let value) = self.wrappedValue {
                    return value
                } else {
                    fatalError("The primitive is no longer a line.")
                }
            },
            set: { self.wrappedValue = .line($0) }
        )
    }
}
