//
//  GraphicPrimitive.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 21.06.25.
//

import Foundation
import CoreGraphics
import AppKit

/// A type-erased wrapper so we can store heterogeneous primitives in one array.
enum AnyPrimitive: GraphicPrimitive, CanvasPrimitive, Codable, Hashable {

    case line(LinePrimitive)
    case rectangle(RectanglePrimitive)
    case circle(CirclePrimitive)
 
    var id: UUID {
        switch self {
        case .line(let line): return line.id
        case .rectangle(let rectangle): return rectangle.id
        case .circle(let circle): return circle.id
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
            case .line(var line): line.position = newValue; self = .line(line)
            case .rectangle(var rectangle): rectangle.position = newValue; self = .rectangle(rectangle)
            case .circle(var circle): circle.position = newValue; self = .circle(circle)
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
            case .line(var line): line.rotation = newValue; self = .line(line)
            case .rectangle(var rectangle): rectangle.rotation = newValue; self = .rectangle(rectangle)
            case .circle(var circle): circle.rotation = newValue; self = .circle(circle)
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
            case .line(var line): line.strokeWidth = newValue; self = .line(line)
            case .rectangle(var rectangle): rectangle.strokeWidth = newValue; self = .rectangle(rectangle)
            case .circle(var circle): circle.strokeWidth = newValue; self = .circle(circle)
            }
        }
    }

    var color: SDColor {
        get {
            switch self {
            case .line(let line): return line.color
            case .rectangle(let rectangle): return rectangle.color
            case .circle(let circle): return circle.color
            }
        }
        set {
            switch self {
            case .line(var line): line.color = newValue; self = .line(line)
            case .rectangle(var rectangle): rectangle.color = newValue; self = .rectangle(rectangle)
            case .circle(var circle): circle.color = newValue; self = .circle(circle)
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
            case .line(var line): line.filled = newValue; self = .line(line)
            case .rectangle(var rectangle): rectangle.filled = newValue; self = .rectangle(rectangle)
            case .circle(var circle): circle.filled = newValue; self = .circle(circle)
            }
        }
    }

    // MARK: - Unified Path
    func makePath(offset: CGPoint = .zero) -> CGPath {
        switch self {
        case .line(let line): return line.makePath(offset: offset)
        case .rectangle(let rectangle): return rectangle.makePath(offset: offset)
        case .circle(let circle): return circle.makePath(offset: offset)
        }
    }

    func handles() -> [Handle] {
        switch self {
        case .line(let line): return line.handles()
        case .rectangle(let rectangle): return rectangle.handles()
        case .circle(let circle): return circle.handles()
        }
    }

    mutating func updateHandle(
        _ kind: Handle.Kind,
        to newPos: CGPoint,
        opposite opp: CGPoint? = nil
    ) {
        switch self {
        case .line(var line): line.updateHandle(kind, to: newPos, opposite: opp); self = .line(line)
        case .rectangle(var rectangle): rectangle.updateHandle(kind, to: newPos, opposite: opp); self = .rectangle(rectangle)
        case .circle(var circle): circle.updateHandle(kind, to: newPos, opposite: opp); self = .circle(circle)
        }
    }
}

extension AnyPrimitive {
    func shifted(by delta: CGPoint) -> AnyPrimitive {
        switch self {
        case .line(var line):
            line.start -= delta
            line.end -= delta
            return .line(line)
        case .rectangle(var rectangle):
            rectangle.position -= delta
            return .rectangle(rectangle)
        case .circle(var circle):
            circle.position -= delta
            return .circle(circle)
        }
    }
}
