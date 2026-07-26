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
            case .arc:
                if let arcBinding = $primitive.arc {
                    ArcPropertiesView(arc: arcBinding)
                }
            case .polyline:
                if let polylineBinding = $primitive.polyline {
                    PolylinePropertiesView(polyline: polylineBinding)
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

struct ArcPropertiesView: View {
    @Binding var arc: CanvasArc

    private var startAngleDegrees: Binding<CGFloat> {
        Binding(
            get: { arc.startAngle * 180 / .pi },
            set: { arc.startAngle = $0 * .pi / 180 }
        )
    }

    private var endAngleDegrees: Binding<CGFloat> {
        Binding(
            get: { arc.endAngle * 180 / .pi },
            set: { arc.endAngle = $0 * .pi / 180 }
        )
    }

    var body: some View {

        InspectorSection("Transform") {

            PointControlView(
                title: "Center",
                point: $arc.position,
                displayOffset: PaperSize.component.centerOffset()
            )

            InspectorRow("Radius", style: .leading) {
                InspectorNumericField(value: $arc.radius, unit: "mm")
            }

            InspectorRow("Angles", style: .leading) {
                InspectorNumericField(label: "Start", value: startAngleDegrees, maxDecimalPlaces: 1, unit: "°")
                InspectorNumericField(label: "End", value: endAngleDegrees, maxDecimalPlaces: 1, unit: "°")
            }

            RotationControlView(object: $arc)

        }

        Divider()
        PrimitiveStyleControlView(object: $arc)

    }
}

struct PolylinePropertiesView: View {
    @Binding var polyline: CanvasPolyline

    var body: some View {

        InspectorSection("Transform") {

            PointControlView(
                title: "Position",
                point: $polyline.position,
                displayOffset: PaperSize.component.centerOffset()
            )

            RotationControlView(object: $polyline)

            InspectorRow("Points") {
                Text("\(polyline.points.count)")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            InspectorRow("Closed") {
                Toggle("Closed", isOn: $polyline.isClosed)
                    .labelsHidden()
            }

        }

        Divider()
        PrimitiveStyleControlView(object: $polyline)

    }
}

// Allows creating bindings to the specific values within an enum binding.
