//
//  CanvasText.swift
//  CircuitPro
//
//  Created by Codex on 12/30/25.
//

import AppKit
import CoreGraphics

/// A canvas-space representation of a text element, used for rendering and interaction.
struct CanvasText: Drawable, Bounded, HitTestable, Transformable, Layerable {

    var resolvedText: CircuitText.Resolved
    var displayText: String

    /// The owning component instance ID (used to persist edits).
    var ownerID: UUID
    var target: TextTarget

    /// The owner's transform in world space.
    var ownerPosition: CGPoint
    var ownerRotation: CGFloat

    var worldPosition: CGPoint {
        get { resolvedText.relativePosition.applying(ownerTransform) }
        set {
            let oldWorldPos = worldPosition
            let inverseOwner = ownerTransform.inverted()
            resolvedText.relativePosition = newValue.applying(inverseOwner)

            // Text is special: when moving the text, the anchor usually moves with it
            // to keep the relative relationship.
            let delta = CGPoint(x: newValue.x - oldWorldPos.x, y: newValue.y - oldWorldPos.y)
            let newAnchorWorld = CGPoint(
                x: worldAnchorPosition.x + delta.x, y: worldAnchorPosition.y + delta.y)
            resolvedText.anchorPosition = newAnchorWorld.applying(inverseOwner)
        }
    }

    var worldRotation: CGFloat {
        ownerRotation + resolvedText.cardinalRotation.radians
    }

    var worldAnchorPosition: CGPoint {
        get { resolvedText.anchorPosition.applying(ownerTransform) }
        set {
            let inverseOwner = ownerTransform.inverted()
            resolvedText.anchorPosition = newValue.applying(inverseOwner)
        }
    }

    var layerId: UUID?
    var showsAnchorGuides: Bool = false

    init(
        resolvedText: CircuitText.Resolved,
        displayText: String,
        ownerID: UUID,
        target: TextTarget,
        ownerPosition: CGPoint = .zero,
        ownerRotation: CGFloat = 0,
        layerId: UUID? = nil,
        showsAnchorGuides: Bool = false
    ) {
        self.resolvedText = resolvedText
        self.displayText = displayText
        self.ownerID = ownerID
        self.target = target
        self.ownerPosition = ownerPosition
        self.ownerRotation = ownerRotation
        self.layerId = layerId
        self.showsAnchorGuides = showsAnchorGuides
    }

    var isVisible: Bool { resolvedText.isVisible }
    var font: NSFont { resolvedText.font.nsFont }
    var color: CGColor { resolvedText.color.cgColor }

    var ownerTransform: CGAffineTransform {
        CGAffineTransform(translationX: ownerPosition.x, y: ownerPosition.y)
            .rotated(by: ownerRotation)
    }

    var worldTransform: CGAffineTransform {
        CGAffineTransform(translationX: worldPosition.x, y: worldPosition.y)
            .rotated(by: worldRotation)
    }

    // MARK: - Drawable

    var id: UUID {
        GraphTextID.makeID(for: resolvedText.source, ownerID: ownerID, fallback: resolvedText.id)
    }

    var renderBounds: CGRect {
        let path = worldPath()
        return path.boundingBoxOfPath
    }

    var hitTestPriority: Int { 5 }

    var boundingBox: CGRect {
        renderBounds
    }

    func makeDrawingPrimitives(in context: RenderContext) -> [LayeredDrawingPrimitive] {
        guard isVisible else { return [] }

        let path = worldPath()
        guard !path.isEmpty else { return [] }

        var primitives: [DrawingPrimitive] = []

        // Main text primitive
        primitives.append(.fill(path: path, color: context.environment.canvasTheme.textColor))

        // Anchor guides if active
        if showsAnchorGuides {
            let guidePath = CGMutablePath()
            // Draw a cross at the anchor point
            let s: CGFloat = 4 / context.magnification
            guidePath.move(to: CGPoint(x: worldAnchorPosition.x - s, y: worldAnchorPosition.y))
            guidePath.addLine(to: CGPoint(x: worldAnchorPosition.x + s, y: worldAnchorPosition.y))
            guidePath.move(to: CGPoint(x: worldAnchorPosition.x, y: worldAnchorPosition.y - s))
            guidePath.addLine(to: CGPoint(x: worldAnchorPosition.x, y: worldAnchorPosition.y + s))

            primitives.append(
                .stroke(
                    path: guidePath, color: NSColor.systemOrange.cgColor,
                    lineWidth: 1 / context.magnification))
        }

        return primitives.map { LayeredDrawingPrimitive($0, layerId: layerId) }
    }

    func haloPath() -> CGPath? {
        worldPath()
    }

    func hitTest(point: CGPoint, tolerance: CGFloat) -> Bool {
        let path = worldPath()
        let hitArea = path.copy(
            strokingWithWidth: tolerance * 2, lineCap: .round, lineJoin: .round, miterLimit: 10)
        return path.contains(point) || hitArea.contains(point)
    }

    // MARK: - Transformable

    var position: CGPoint {
        get { worldPosition }
        set { worldPosition = newValue }
    }

    var rotation: CGFloat {
        get { worldRotation }
        set { resolvedText.cardinalRotation = .closest(to: newValue - ownerRotation) }
    }

    // MARK: - Helpers

    func localPath() -> CGPath {
        let untransformedPath = TextUtilities.path(for: displayText, font: font)
        guard !untransformedPath.isEmpty else { return untransformedPath }

        let targetPoint = resolvedText.anchor.point(in: untransformedPath.boundingBoxOfPath)
        let offset = CGVector(dx: -targetPoint.x, dy: -targetPoint.y)
        var transform = CGAffineTransform(translationX: offset.dx, y: offset.dy)
        return untransformedPath.copy(using: &transform) ?? untransformedPath
    }

    func worldPath() -> CGPath {
        let local = localPath()
        guard !local.isEmpty else { return local }
        var transform = worldTransform
        return local.copy(using: &transform) ?? local
    }
}

extension CanvasText: CanvasItem {}
