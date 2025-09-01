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

    var textModel: TextModel {
         didSet {
             // Check if a meaningful change occurred to avoid commit loops.
             guard textModel != oldValue else { return }

             // Redraw the canvas to reflect the visual change immediately.
             parent?.onNeedsRedraw?()
             onNeedsRedraw?()
             
             // --- THE FIX ---
             // If this node is an AnchoredTextNode, it knows how to save its state.
             // We tell it to persist the change back to the main data model.
             if let anchoredself = self as? AnchoredTextNode {
                 anchoredself.commitChanges()
             }
         }
     }

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

    private func makeFinalPath() -> CGPath {
         let untransformedPath = textModel.makeTextPath()
         guard !untransformedPath.isEmpty else { return untransformedPath }

         let bounds = untransformedPath.boundingBoxOfPath

         // Calculate the target point on the bounds that should be moved to the origin (0,0).
         let targetX: CGFloat
         let targetY: CGFloat

         // Determine the target X coordinate based on the anchor.
         switch textModel.anchor {
         case .topLeading, .leading, .bottomLeading:
             targetX = bounds.minX
         case .top, .center, .bottom:
             targetX = bounds.midX
         case .topTrailing, .trailing, .bottomTrailing:
             targetX = bounds.maxX
         }

         // Determine the target Y coordinate based on the anchor.
         switch textModel.anchor {
         case .topLeading, .top, .topTrailing:
             // NOTE: In a Y-up coordinate system (like AppKit's views),
             // the maximum Y value is the top of the bounding box.
             targetY = bounds.maxY
         case .leading, .center, .trailing:
             targetY = bounds.midY
         case .bottomLeading, .bottom, .bottomTrailing:
             targetY = bounds.minY
         }
         
         // The offset is the vector needed to move the target point to (0,0).
         let offset = CGVector(dx: -targetX, dy: -targetY)
         
         // Apply the offset transform to the path.
         var transform = CGAffineTransform(translationX: offset.dx, y: offset.dy)
         return untransformedPath.copy(using: &transform) ?? untransformedPath
     }

     // MARK: - Drawable Conformance

     override func makeDrawingPrimitives() -> [DrawingPrimitive] {
         guard isVisible else { return [] }
         let finalPath = makeFinalPath()
         guard !finalPath.isEmpty else { return [] }
       
         return [.fill(
             path: finalPath,
             color: textModel.color.cgColor
         )]
     }

     override func makeHaloPath() -> CGPath? {
         guard isVisible else { return nil }
         let finalPath = makeFinalPath()
         guard !finalPath.isEmpty else { return nil }
         
         return finalPath.copy(
             strokingWithWidth: 1.0,
             lineCap: .round,
             lineJoin: .round,
             miterLimit: 1.0
         )
     }

    // MARK: - Hittable Conformance

    override func hitTest(_ point: CGPoint, tolerance: CGFloat) -> CanvasHitTarget? {
        // The `point` parameter is in the node's local coordinate space.
        let localPath = makeFinalPath()
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
        let p = makeFinalPath()
         let box = p.boundingBoxOfPath
         return box.isNull ? .null : box
     }
}
