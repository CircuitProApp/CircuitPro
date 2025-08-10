import AppKit

/// A scene graph node that represents a `Pad` data model on the canvas.
///
/// This `CanvasElement` wraps a `Pad` struct and is responsible for its drawing
/// and hit-testing logic. It relies on the geometry calculations defined in the
/// `Pad+Geometry` extension to generate its visual representation.
@Observable
class PadNode: BaseNode {

    // MARK: - Properties

    var pad: Pad {
        didSet {
            onNeedsRedraw?()
        }
    }

    enum Part: Hashable {
        case body
    }

    // MARK: - Overridden Scene Graph Properties

    override var position: CGPoint {
        get { pad.position }
        set { pad.position = newValue }
    }

    override var rotation: CGFloat {
        get { pad.rotation }
        set { pad.rotation = newValue }
    }

    // MARK: - Initialization

    init(pad: Pad) {
        self.pad = pad
        super.init(id: pad.id)
    }

    // MARK: - Drawable Conformance

    // UPDATED: This method now returns an array of DrawingPrimitive.
    override func makeDrawingPrimitives() -> [DrawingPrimitive] {
        // 1. Generate the pad's final composite path in its local space.
        let localPath = pad.calculateCompositePath()
        guard !localPath.isEmpty else { return [] }

        // 2. Define the appearance.
        let copperColor = NSColor.systemRed.cgColor

        // 3. Return a specific .fill command for the renderer to process.
        return [.fill(path: localPath, color: copperColor)]
    }

    // UNCHANGED: This method's logic and return type are already correct for the new system.
    override func makeHaloPath() -> CGPath? {
        let haloWidth: CGFloat = 1.0

        let shapePath = pad.calculateShapePath()
        guard !shapePath.isEmpty else { return nil }

        let thickOutline = shapePath.copy(strokingWithWidth: haloWidth * 2, lineCap: .round, lineJoin: .round, miterLimit: 1)
        let enlargedShape = thickOutline.union(shapePath)

        let localHaloPath: CGPath
        if pad.type == .throughHole, let drillDiameter = pad.drillDiameter, drillDiameter > 0 {
            let drillMaskPath = CGMutablePath()
            let drillRadius = drillDiameter / 2
            let drillRect = CGRect(x: -drillRadius, y: -drillRadius, width: drillDiameter, height: drillDiameter)
            drillMaskPath.addPath(CGPath(ellipseIn: drillRect, transform: nil))
            localHaloPath = enlargedShape.subtracting(drillMaskPath)
        } else {
            localHaloPath = enlargedShape
        }

        return localHaloPath.isEmpty ? nil : localHaloPath
    }

    // MARK: - Hittable Conformance (Local Space)

    // UNCHANGED: This method's logic is self-contained and already operates on paths, so no update is needed.
    override func hitTest(_ point: CGPoint, tolerance: CGFloat) -> CanvasHitTarget? {
        let bodyPath = pad.calculateCompositePath()
        
        // Check for hit on the filled area first.
        if bodyPath.contains(point) {
            return CanvasHitTarget(node: self, partIdentifier: Part.body, position: self.convert(point, to: nil))
        }

        // For small or hollow pads, also check a slightly larger area.
        let hitArea = bodyPath.copy(strokingWithWidth: tolerance, lineCap: .round, lineJoin: .round, miterLimit: 1)
        if hitArea.contains(point) {
            return CanvasHitTarget(node: self, partIdentifier: Part.body, position: self.convert(point, to: nil))
        }
        
        return nil
    }
}
