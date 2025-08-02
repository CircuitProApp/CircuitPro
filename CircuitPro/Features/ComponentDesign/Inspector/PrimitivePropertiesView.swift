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
        VStack(alignment: .leading, spacing: 15) {
            Text("\(primitive.displayName) Properties")
                .font(.title3.weight(.semibold))
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
        .padding(10)
    }
}

// MARK: - Properties Views for Each Primitive Type

struct RectanglePropertiesView: View {
    @Binding var rectangle: RectanglePrimitive
    
    
    var body: some View {
       
            InspectorSection("Transform") {
          
                    PointControlView(
                        title: "Position",
                        point: $rectangle.position,
                        displayOffset: PaperSize.component.centerOffset()
                    )
                
                InspectorRow("Size") {
                  
                    InspectorNumericField(title: "W", value: $rectangle.size.width, unit: "mm")
                    InspectorNumericField(title: "H", value: $rectangle.size.height, unit: "mm")
                    
            
                }
          
                RotationControlView(object: $rectangle)
                
            }
         
            Divider()
            PrimitiveStyleControlView(object: $rectangle)        

    }
}

struct CirclePropertiesView: View {
    @Binding var circle: CirclePrimitive
    
    var body: some View {

           
            InspectorSection("Transform") {

                PointControlView(
                    title: "Position",
                    point: $circle.position,
                    displayOffset: PaperSize.component.centerOffset()
                )
                
          
                InspectorRow("Radius") {
                    InspectorNumericField(value: $circle.radius, unit: "mm")
                    Color.clear
                }
             
                RotationControlView(object: $circle)
                
            }
    
            Divider()
            PrimitiveStyleControlView(object: $circle)
            
  
    }
}

struct LinePropertiesView: View {
    @Binding var line: LinePrimitive
    
    var body: some View {

            InspectorSection("Transform") {
                PointControlView(
                    title: "Start Point",
                    point: $line.start,
                    displayOffset: PaperSize.component.centerOffset(),
                )
                PointControlView(
                    title: "End Point",
                    point: $line.end,
                    displayOffset: PaperSize.component.centerOffset()
                )
                RotationControlView(object: $line)
            }

            Divider()
            PrimitiveStyleControlView(object: $line)
    
 
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
