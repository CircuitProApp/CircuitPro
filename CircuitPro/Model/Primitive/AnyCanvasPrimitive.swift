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

    var id: UUID {
        switch self {
        case .line(let line): return line.id
        case .rectangle(let rectangle): return rectangle.id
        case .circle(let circle): return circle.id
        }
    }

    var layerId: UUID? {
        get {
            switch self {
            case .line(let primitive): return primitive.layerId
            case .rectangle(let primitive): return primitive.layerId
            case .circle(let primitive): return primitive.layerId
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
            }
        }
    }

    var rotation: CGFloat {
        get {
            switch self {
            case .line(let line): return line.rotation
            case .rectangle(let rectangle): return rectangle.rotation
            case .circle(let circle): return circle.rotation
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
            }
        }
    }

    var strokeWidth: CGFloat {
        get {
            switch self {
            case .line(let line): return line.strokeWidth
            case .rectangle(let rectangle): return rectangle.strokeWidth
            case .circle(let circle): return circle.strokeWidth
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
            }
        }
    }

    var filled: Bool {
        get {
            switch self {
            case .line(let line): return line.filled
            case .rectangle(let rectangle): return rectangle.filled
            case .circle(let circle): return circle.filled
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
}
