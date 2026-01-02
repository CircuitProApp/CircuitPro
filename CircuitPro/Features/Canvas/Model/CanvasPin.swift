//
//  CanvasPin.swift
//  CircuitPro
//
//  Created by Codex on 12/30/25.
//

import AppKit
import CoreGraphics

/// A canvas-space representation of a pin, used for rendering and interaction.
struct CanvasPin: Drawable, Bounded, HitTestable, Transformable {

    var pin: Pin
    var ownerID: UUID?
    var ownerPosition: CGPoint
    var ownerRotation: CGFloat
    var isSelectable: Bool

    init(
        pin: Pin,
        ownerID: UUID? = nil,
        ownerPosition: CGPoint = .zero,
        ownerRotation: CGFloat = 0,
        isSelectable: Bool = true
    ) {
        self.pin = pin
        self.ownerID = ownerID
        self.ownerPosition = ownerPosition
        self.ownerRotation = ownerRotation
        self.isSelectable = isSelectable
    }

    var ownerTransform: CGAffineTransform {
        CGAffineTransform(translationX: ownerPosition.x, y: ownerPosition.y)
            .rotated(by: ownerRotation)
    }

    var worldTransform: CGAffineTransform {
        CGAffineTransform(translationX: pin.position.x, y: pin.position.y)
            .concatenating(ownerTransform)
    }

    // MARK: - Drawable

    var id: UUID { GraphPinID.makeID(ownerID: ownerID, pinID: pin.id) }

    var renderBounds: CGRect {
        let worldPos = pin.position.applying(ownerTransform)
        let size: CGFloat = 10
        return CGRect(
            x: worldPos.x - size / 2,
            y: worldPos.y - size / 2,
            width: size,
            height: size
        )
    }

    var hitTestPriority: Int { 10 }

    var boundingBox: CGRect {
        renderBounds
    }

    func makeDrawingPrimitives(in context: RenderContext) -> [LayeredDrawingPrimitive] {
        let localPrimitives = pin.makeDrawingPrimitives()
        guard !localPrimitives.isEmpty else { return [] }

        var transform = worldTransform
        let worldPrimitives = localPrimitives.map { $0.applying(transform: &transform) }

        return worldPrimitives.map { LayeredDrawingPrimitive($0, layerId: nil) }
    }

    func haloPath() -> CGPath? {
        let worldPos = pin.position.applying(ownerTransform)
        let size: CGFloat = 12
        return CGPath(
            ellipseIn: CGRect(
                x: worldPos.x - size / 2, y: worldPos.y - size / 2, width: size, height: size),
            transform: nil
        )
    }

    func hitTest(point: CGPoint, tolerance: CGFloat) -> Bool {
        let worldPos = pin.position.applying(ownerTransform)
        let distance = hypot(point.x - worldPos.x, point.y - worldPos.y)
        return distance <= tolerance + 5
    }

    // MARK: - Transformable

    var position: CGPoint {
        get {
            pin.position.applying(ownerTransform)
        }
        set {
            let inverseOwner = ownerTransform.inverted()
            pin.position = newValue.applying(inverseOwner)
        }
    }

    var rotation: CGFloat {
        get {
            ownerRotation + pin.rotation
        }
        set {
            pin.rotation = newValue - ownerRotation
        }
    }
}

extension CanvasPin: CanvasItem {}

extension CanvasPin: ConnectionPoint {}

extension CanvasPin: ConnectionPointProvider {
    var connectionPoints: [any ConnectionPoint] { [self] }
}
