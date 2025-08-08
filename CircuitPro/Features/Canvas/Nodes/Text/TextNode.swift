//
//  TextNode.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/6/25.
//


import AppKit

/// A scene graph node that represents a `TextModel` on the canvas.
@Observable
class TextNode: BaseNode {

    // MARK: - Properties

    var textModel: TextModel

    /// Defines the distinct, hittable parts of a TextNode.
    enum Part: Hashable {
        case body
    }

    // MARK: - Overridden Scene Graph Properties

    override var position: CGPoint {
        get { textModel.position }
        set { textModel.position = newValue }
    }

    override var rotation: CGFloat {
        get { textModel.cardinalRotation.radians }
        set { textModel.cardinalRotation = .closestWithDiagonals(to: newValue) }
    }

    // MARK: - Initialization

    init(textModel: TextModel) {
        self.textModel = textModel
        super.init(id: textModel.id)
    }

    // MARK: - Drawable Conformance

    override func makeDrawingPrimitives() -> [DrawingPrimitive] {

        let localPath = textModel.makeTextPath()
      
        return [.fill(
                path: localPath,
                color: textModel.color
            )]
    }

    override func makeHaloPath() -> CGPath? {
        let localPath = textModel.makeTextPath()
        // The halo is a stroked version of the local path.
        return localPath.copy(
            strokingWithWidth: 2.0, // Adjust for desired halo thickness
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 1.0
        )
    }

    // MARK: - Hittable Conformance

    override func hitTest(_ point: CGPoint, tolerance: CGFloat) -> CanvasHitTarget? {
        // The `point` parameter is in the node's local coordinate space.
        let localPath = textModel.makeTextPath()
        let localBounds = localPath.boundingBoxOfPath

        // Check for a hit within the local bounding box, expanded by the tolerance.
        if localBounds.insetBy(dx: -tolerance, dy: -tolerance).contains(point) {
            return CanvasHitTarget(
                node: self,
                partIdentifier: Part.body,
                // The hit position must be converted back to world space for the canvas.
                position: self.convert(point, to: nil)
            )
        }

        return nil
    }
    
    override var boundingBox: CGRect {
        let p = textModel.makeTextPath()
         let box = p.boundingBoxOfPath
         return box.isNull ? .null : box
     }
}
