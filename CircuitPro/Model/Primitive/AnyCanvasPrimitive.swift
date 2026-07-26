//
//  AnyCanvasPrimitive.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 21.06.25.
//

import CoreGraphics
import Foundation
import SwiftUI

/// A type-erased wrapper so we can store heterogeneous canvas primitives in one array.
enum AnyCanvasPrimitive: CanvasPrimitive, Identifiable, Hashable {

    case line(CanvasLine)
    case rectangle(CanvasRectangle)
    case circle(CanvasCircle)
    case arc(CanvasArc)
    case polyline(CanvasPolyline)

    var id: UUID {
        switch self {
        case .line(let line): return line.id
        case .rectangle(let rectangle): return rectangle.id
        case .circle(let circle): return circle.id
        case .arc(let arc): return arc.id
        case .polyline(let polyline): return polyline.id
        }
    }

    var layerId: UUID? {
        get {
            switch self {
            case .line(let primitive): return primitive.layerId
            case .rectangle(let primitive): return primitive.layerId
            case .circle(let primitive): return primitive.layerId
            case .arc(let primitive): return primitive.layerId
            case .polyline(let primitive): return primitive.layerId
            }
        }
        set {
            switch self {
            case .line(var primitive):
                primitive.layerId = newValue
                self = .line(primitive)
            case .rectangle(var primitive):
                primitive.layerId = newValue
                self = .rectangle(primitive)
            case .circle(var primitive):
                primitive.layerId = newValue
                self = .circle(primitive)
            case .arc(var primitive):
                primitive.layerId = newValue
                self = .arc(primitive)
            case .polyline(var primitive):
                primitive.layerId = newValue
                self = .polyline(primitive)
            }
        }
    }

    // MARK: - Mutating accessors that need to write back into enum
    var position: CGPoint {
        get {
            switch self {
            case .line(let line): return line.position
            case .rectangle(let rectangle): return rectangle.position
            case .circle(let circle): return circle.position
            case .arc(let arc): return arc.position
            case .polyline(let polyline): return polyline.position
            }
        }
        set {
            switch self {
            case .line(var line):
                line.position = newValue
                self = .line(line)
            case .rectangle(var rectangle):
                rectangle.position = newValue
                self = .rectangle(rectangle)
            case .circle(var circle):
                circle.position = newValue
                self = .circle(circle)
            case .arc(var arc):
                arc.position = newValue
                self = .arc(arc)
            case .polyline(var polyline):
                polyline.position = newValue
                self = .polyline(polyline)
            }
        }
    }

    var rotation: CGFloat {
        get {
            switch self {
            case .line(let line): return line.rotation
            case .rectangle(let rectangle): return rectangle.rotation
            case .circle(let circle): return circle.rotation
            case .arc(let arc): return arc.rotation
            case .polyline(let polyline): return polyline.rotation
            }
        }
        set {
            switch self {
            case .line(var line):
                line.rotation = newValue
                self = .line(line)
            case .rectangle(var rectangle):
                rectangle.rotation = newValue
                self = .rectangle(rectangle)
            case .circle(var circle):
                circle.rotation = newValue
                self = .circle(circle)
            case .arc(var arc):
                arc.rotation = newValue
                self = .arc(arc)
            case .polyline(var polyline):
                polyline.rotation = newValue
                self = .polyline(polyline)
            }
        }
    }

    var strokeWidth: CGFloat {
        get {
            switch self {
            case .line(let line): return line.strokeWidth
            case .rectangle(let rectangle): return rectangle.strokeWidth
            case .circle(let circle): return circle.strokeWidth
            case .arc(let arc): return arc.strokeWidth
            case .polyline(let polyline): return polyline.strokeWidth
            }
        }
        set {
            switch self {
            case .line(var line):
                line.strokeWidth = newValue
                self = .line(line)
            case .rectangle(var rectangle):
                rectangle.strokeWidth = newValue
                self = .rectangle(rectangle)
            case .circle(var circle):
                circle.strokeWidth = newValue
                self = .circle(circle)
            case .arc(var arc):
                arc.strokeWidth = newValue
                self = .arc(arc)
            case .polyline(var polyline):
                polyline.strokeWidth = newValue
                self = .polyline(polyline)
            }
        }
    }

    var filled: Bool {
        get {
            switch self {
            case .line(let line): return line.filled
            case .rectangle(let rectangle): return rectangle.filled
            case .circle(let circle): return circle.filled
            case .arc(let arc): return arc.filled
            case .polyline(let polyline): return polyline.filled
            }
        }
        set {
            switch self {
            case .line(var line):
                line.filled = newValue
                self = .line(line)
            case .rectangle(var rectangle):
                rectangle.filled = newValue
                self = .rectangle(rectangle)
            case .circle(var circle):
                circle.filled = newValue
                self = .circle(circle)
            case .arc(var arc):
                arc.filled = newValue
                self = .arc(arc)
            case .polyline(var polyline):
                polyline.filled = newValue
                self = .polyline(polyline)
            }
        }
    }

}

extension AnyCanvasPrimitive: CanvasItem {}

extension AnyCanvasPrimitive: MultiLayerable {
    var layerIds: [UUID] {
        get { layerId.map { [$0] } ?? [] }
        set { layerId = newValue.first }
    }
}

extension AnyCanvasPrimitive {
    var displayName: String {
        switch self {
        case .rectangle:
            "Rectangle"
        case .circle:
            "Circle"
        case .line:
            "Line"
        case .arc:
            "Arc"
        case .polyline:
            "Polyline"
        }
    }
}

extension AnyCanvasPrimitive {
    var symbol: String {
        switch self {
        case .rectangle:
            CircuitProSymbols.Graphic.rectangle
        case .circle:
            CircuitProSymbols.Graphic.circle
        case .line:
            CircuitProSymbols.Graphic.line
        case .arc:
            CircuitProSymbols.Graphic.arc
        case .polyline:
            CircuitProSymbols.Graphic.polyline
        }
    }
}

// Allows creating bindings to the specific canvas primitive within an AnyCanvasPrimitive binding.
extension Binding where Value == AnyCanvasPrimitive {
    var rectangle: Binding<CanvasRectangle>? {
        guard case .rectangle = self.wrappedValue else { return nil }
        return Binding<CanvasRectangle>(
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

    var circle: Binding<CanvasCircle>? {
        guard case .circle = self.wrappedValue else { return nil }
        return Binding<CanvasCircle>(
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

    var line: Binding<CanvasLine>? {
        guard case .line = self.wrappedValue else { return nil }
        return Binding<CanvasLine>(
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

    var arc: Binding<CanvasArc>? {
        guard case .arc = self.wrappedValue else { return nil }
        return Binding<CanvasArc>(
            get: {
                if case .arc(let value) = self.wrappedValue {
                    return value
                } else {
                    fatalError("The primitive is no longer an arc.")
                }
            },
            set: { self.wrappedValue = .arc($0) }
        )
    }

    var polyline: Binding<CanvasPolyline>? {
        guard case .polyline = self.wrappedValue else { return nil }
        return Binding<CanvasPolyline>(
            get: {
                if case .polyline(let value) = self.wrappedValue {
                    return value
                } else {
                    fatalError("The primitive is no longer a polyline.")
                }
            },
            set: { self.wrappedValue = .polyline($0) }
        )
    }
}
