import Foundation
import CoreGraphics
import AppKit

/// A type-erased wrapper so we can store heterogeneous primitives in one array.
enum AnyPrimitive: GraphicPrimitive, Codable, Hashable {

    case circle(CirclePrimitive)
    case rectangle(RectanglePrimitive)
    case line(LinePrimitive)
 
    var uuid: UUID {
        switch self {
        case .circle(let circle): return circle.id
        case .rectangle(let rectangle): return rectangle.id
        case .line(let line): return line.id
        }
    }

    var id: UUID { uuid }

    // MARK: - Mutating accessors that need to write back into enum

    var position: CGPoint {
        get {
            switch self {
            case .circle(let circle): return circle.position
            case .rectangle(let rectangle): return rectangle.position
            case .line(let line): return line.position
            }
        }
        set {
            switch self {
            case .circle(var circle): circle.position = newValue; self = .circle(circle)
            case .rectangle(var rectangle): rectangle.position = newValue; self = .rectangle(rectangle)
            case .line(var line): line.position = newValue; self = .line(line)
            }
        }
    }

    var rotation: CGFloat {
        get {
            switch self {
            case .circle(let circle): return circle.rotation
            case .rectangle(let rectangle): return rectangle.rotation
            case .line(let line): return line.rotation
            }
        }
        set {
            switch self {
            case .circle(var circle): circle.rotation = newValue; self = .circle(circle)
            case .rectangle(var rectangle): rectangle.rotation = newValue; self = .rectangle(rectangle)
            case .line(var line): line.rotation = newValue; self = .line(line)
            }
        }
    }

    var strokeWidth: CGFloat {
        get {
            switch self {
            case .circle(let circle): return circle.strokeWidth
            case .rectangle(let rectangle): return rectangle.strokeWidth
            case .line(let line): return line.strokeWidth
            }
        }
        set {
            switch self {
            case .circle(var circle): circle.strokeWidth = newValue; self = .circle(circle)
            case .rectangle(var rectangle): rectangle.strokeWidth = newValue; self = .rectangle(rectangle)
            case .line(var line): line.strokeWidth = newValue; self = .line(line)
            }
        }
    }

    var color: SDColor {
        get {
            switch self {
            case .circle(let circle): return circle.color
            case .rectangle(let rectangle): return rectangle.color
            case .line(let line): return line.color
            }
        }
        set {
            switch self {
            case .circle(var circle): circle.color = newValue; self = .circle(circle)
            case .rectangle(var rectangle): rectangle.color = newValue; self = .rectangle(rectangle)
            case .line(var line): line.color = newValue; self = .line(line)
            }
        }
    }

    var filled: Bool {
        get {
            switch self {
            case .circle(let circle): return circle.filled
            case .rectangle(let rectangle): return rectangle.filled
            case .line(let line): return line.filled
            }
        }
        set {
            switch self {
            case .circle(var circle): circle.filled = newValue; self = .circle(circle)
            case .rectangle(var rectangle): rectangle.filled = newValue; self = .rectangle(rectangle)
            case .line(var line): line.filled = newValue; self = .line(line)
            }
        }
    }

    // MARK: - Unified Path

    func makePath(offset: CGPoint = .zero) -> CGPath {
        switch self {
        case .circle(let circle): return circle.makePath(offset: offset)
        case .rectangle(let rectangle): return rectangle.makePath(offset: offset)
        case .line(let line): return line.makePath(offset: offset)
        }
    }

    // MARK: - Hit Testing

    func systemHitTest(at point: CGPoint, tolerance: CGFloat = 5) -> Bool {
        let path = makePath()
        if filled {
            return path.contains(point)
        } else {
            let fat = path.copy(
                strokingWithWidth: strokeWidth + tolerance,
                lineCap: .round,
                lineJoin: .round,
                miterLimit: 10
            )
            return fat.contains(point)
        }
    }

    func handles() -> [Handle] {
        switch self {
        case .circle(let circle): return circle.handles()
        case .rectangle(let rectangle): return rectangle.handles()
        case .line(let line): return line.handles()
        }
    }

    mutating func updateHandle(
        _ kind: Handle.Kind,
        to newPos: CGPoint,
        opposite opp: CGPoint? = nil
    ) {
        switch self {
        case .circle(var circle): circle.updateHandle(kind, to: newPos, opposite: opp); self = .circle(circle)
        case .rectangle(var rectangle): rectangle.updateHandle(
            kind,
            to: newPos,
            opposite: opp
        ); self = .rectangle(rectangle)
        case .line(var line): line.updateHandle(kind, to: newPos, opposite: opp); self = .line(line)
        }
    }
}

// MARK: - Convenience rendering helper
extension AnyPrimitive {
    /// Draws the primitive on `ctx`.
    /// When `selected == true` a blue “halo” is rendered.
    func draw(in ctx: CGContext, selected: Bool) {

        let path = makePath()

        // main fill / stroke
        if filled {
            ctx.setFillColor(color.cgColor)
            ctx.addPath(path)
            ctx.fillPath()
        } else {
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(strokeWidth)
            ctx.setLineCap(.round)
            ctx.addPath(path)
            ctx.strokePath()
        }

        // optional selection halo
        if selected {
            let haloWidth = max(strokeWidth * 2, strokeWidth + 3)
            let haloColor = CGColor(
                red: CGFloat(color.red),
                green: CGFloat(color.green),
                blue: CGFloat(color.blue),
                alpha: 0.4
            )
            ctx.setStrokeColor(haloColor)
            ctx.setLineWidth(haloWidth)
            ctx.setLineCap(.round)
            ctx.addPath(path)
            ctx.strokePath()
        }
    }
}
