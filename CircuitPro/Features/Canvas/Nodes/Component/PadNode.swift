// Features/Canvas/Nodes/Component/PadNode.swift

import AppKit

/// A scene graph node that represents a `Pad` data model on the canvas.
@Observable
class PadNode: BaseNode {

    var pad: Pad {
        didSet { invalidateContentBoundingBox() }
    }

    // --- THIS IS THE CORRECTED LOGIC ---
    /// A PadNode is selectable by default, but *not* when it's part of a FootprintNode.
    /// This allows pads to be selected in an editor but not on the main layout canvas.
    override var isSelectable: Bool {
        return !(parent is FootprintNode)
    }

    enum Part: Hashable {
        case body
    }

    override var position: CGPoint {
        get { pad.position }
        set { pad.position = newValue }
    }

    override var rotation: CGFloat {
        get { pad.rotation }
        set { pad.rotation = newValue }
    }

    init(pad: Pad) {
        self.pad = pad
        super.init(id: pad.id)
    }

    override func makeDrawingPrimitives() -> [DrawingPrimitive] {
        let localPath = pad.calculateCompositePath()
        guard !localPath.isEmpty else { return [] }
        let copperColor = NSColor.systemRed.cgColor
        return [.fill(path: localPath, color: copperColor)]
    }

    override func makeHaloPath() -> CGPath? {
        let haloWidth: CGFloat = 1.0
        let shapePath = pad.calculateShapePath()
        guard !shapePath.isEmpty else { return nil }
        let thickOutline = shapePath.copy(strokingWithWidth: haloWidth * 2, lineCap: .round, lineJoin: .round, miterLimit: 1)
        return thickOutline.union(shapePath)
    }

    /// Hit-tests the pad's geometry. It will only return a target if the node is
    /// currently in a selectable state (i.e., not part of a footprint).
    override func hitTest(_ point: CGPoint, tolerance: CGFloat) -> CanvasHitTarget? {
        // --- ADDED: First, check if we are allowed to be selected in the current context. ---
        guard isSelectable else { return nil }
        
        // If we are selectable, then perform the geometry check.
        let bodyPath = pad.calculateCompositePath()
        let hitArea = bodyPath.copy(strokingWithWidth: tolerance, lineCap: .round, lineJoin: .round, miterLimit: 1)
        
        if hitArea.contains(point) {
            return CanvasHitTarget(node: self, partIdentifier: Part.body, position: self.convert(point, to: nil))
        }
        
        return nil
    }
}
