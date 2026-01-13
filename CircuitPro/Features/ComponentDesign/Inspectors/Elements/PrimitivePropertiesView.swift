//
//  PrimitivePropertiesView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/27/25.
//

import SwiftUI

struct PrimitivePropertiesView: View {
    @Binding var primitive: AnyCanvasPrimitive

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("\(primitive.displayName) Properties")
                .font(.title3.weight(.semibold))

            switch primitive {
            case .rectangle:
                // Use the new binding helper, consistent with other cases.
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
            }
        }
        .padding(10)
    }
}

// MARK: - Properties Views for Each Primitive Type

struct RectanglePropertiesView: View {
    @Binding var rectangle: CanvasRectangle


    var body: some View {

            InspectorSection("Transform") {

                    PointControlView(
                        title: "Position",
                        point: $rectangle.position,
                        displayOffset: PaperSize.component.centerOffset()
                    )

                InspectorRow("Size") {

                    InspectorNumericField(label: "W", value: $rectangle.size.width, unit: "mm")
                    InspectorNumericField(label: "H", value: $rectangle.size.height, unit: "mm")


                }

                RotationControlView(object: $rectangle)

            }

            Divider()
            PrimitiveStyleControlView(object: $rectangle)

    }
}

struct CirclePropertiesView: View {
    @Binding var circle: CanvasCircle

    var body: some View {


            InspectorSection("Transform") {

                PointControlView(
                    title: "Position",
                    point: $circle.position,
                    displayOffset: PaperSize.component.centerOffset()
                )


                InspectorRow("Radius", style: .leading) {
                    InspectorNumericField(value: $circle.radius, unit: "mm")

                }

                RotationControlView(object: $circle)

            }

            Divider()
            PrimitiveStyleControlView(object: $circle)


    }
}

struct LinePropertiesView: View {
    @Binding var line: CanvasLine

    var body: some View {

            InspectorSection("Transform") {
                PointControlView(
                    title: "Start Point",
                    point: $line.startPoint,
                    displayOffset: PaperSize.component.centerOffset(),
                )
                PointControlView(
                    title: "End Point",
                    point: $line.endPoint,
                    displayOffset: PaperSize.component.centerOffset()
                )
                RotationControlView(object: $line)
            }

            Divider()
            PrimitiveStyleControlView(object: $line)


    }
}

// Allows creating bindings to the specific values within an enum binding.
