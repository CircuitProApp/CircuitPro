//import AppKit
//
///// Handles click-drag-release marquee selection.
//final class MarqueeSelectionGesture {
//
//    unowned let controller: CanvasController
//
//    // The starting point of the marquee drag.
//    private var origin: CGPoint?
//    
//    // Whether the selection should be added to the existing selection.
//    private var isAdditive: Bool = false
//
//    init(controller: CanvasController) {
//        self.controller = controller
//    }
//
//    /// Begins a marquee selection gesture.
//    /// This should be called by the input coordinator when a drag starts on empty space.
//    func begin(at point: CGPoint, event: NSEvent) {
//        origin = point
//        isAdditive = event.modifierFlags.contains(.shift)
//        
//        // Ensure the controller's marquee state is clean at the start of a new gesture.
//        controller.marqueeRect = nil
//        controller.marqueeSelectedIDs.removeAll()
//    }
//
//    /// Updates the marquee rectangle and recalculates the elements within it.
//    func drag(to point: CGPoint) {
//        guard let origin = self.origin else { return }
//
//        // 1. Calculate the new marquee rectangle and update the controller.
//        // The MarqueeRenderLayer will use this property to draw the marquee.
//        let newRect = CGRect(origin: origin, size: .zero).union(CGRect(origin: point, size: .zero))
//        controller.marqueeRect = newRect
//
//        // 2. Find all canvas elements whose bounding boxes intersect the marquee.
//        let elementIDs = controller.elements
//            .filter { $0.boundingBox.intersects(newRect) }
//            .map(\.id)
//
//        // 3. Find all schematic edges whose bounding boxes intersect the marquee.
//        let edgeIDs = controller.schematicGraph.edges.values.compactMap { edge -> UUID? in
//            guard let startVertex = controller.schematicGraph.vertices[edge.start],
//                  let endVertex = controller.schematicGraph.vertices[edge.end] else {
//                return nil
//            }
//            let edgeRect = CGRect(origin: startVertex.point, size: .zero)
//                .union(.init(origin: endVertex.point, size: .zero))
//            
//            return newRect.intersects(edgeRect) ? edge.id : nil
//        }
//
//        // 4. Update the controller with the set of all items currently inside the marquee.
//        // The ElementsRenderLayer and ConnectionsRenderLayer use this for live highlighting.
//        controller.marqueeSelectedIDs = Set(elementIDs).union(edgeIDs)
//    }
//
//    /// Finalizes the selection and cleans up the gesture's state.
//    func end() {
//        // Only modify the selection if a drag actually happened.
//        if origin != nil {
//            // Merge the temporary marquee selection into the main selection list.
//            if isAdditive {
//                controller.selectedIDs.formUnion(controller.marqueeSelectedIDs)
//            } else {
//                controller.selectedIDs = controller.marqueeSelectedIDs
//            }
//        }
//        
//        // Clean up all transient state from the controller and the gesture itself.
//        controller.marqueeRect = nil
//        controller.marqueeSelectedIDs.removeAll()
//        origin = nil
//        isAdditive = false
//    }
//
//    /// A computed property to check if the gesture is currently in progress.
//    var active: Bool {
//        return origin != nil
//    }
//}
