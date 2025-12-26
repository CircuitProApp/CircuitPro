import AppKit
import Observation

@Observable
class PinNode: BaseNode {

    // MARK: - Properties

    var pin: Pin {
        didSet {
            invalidateContentBoundingBox()

        }
    }

    // --- CHANGE: The graph reference is now optional. ---
    weak var wireEngine: WireEngine?

    enum Part: Hashable {
        case endpoint
        case body
        case nameLabel
        case numberLabel
    }

    override var isSelectable: Bool {
        return !(parent is SymbolNode)
    }

    // MARK: - Overridden Scene Graph Properties

    override var position: CGPoint {
        get { pin.position }
        set { pin.position = newValue }
    }

    override var rotation: CGFloat {
        get { 0 }
        set { pin.rotation = newValue }
    }

    // --- CHANGE: The initializer now accepts an optional graph. ---
    init(pin: Pin, wireEngine: WireEngine? = nil) {
        self.pin = pin
        self.wireEngine = wireEngine
        super.init(id: pin.id)
    }

    // MARK: - Drawable Conformance

    override func makeDrawingPrimitives() -> [DrawingPrimitive] {
        var primitives = pin.makeDrawingPrimitives()

        // --- CHANGE: Safely unwrap the optional graph. ---
        // If there's no graph, or we can't find the corresponding vertex,
        // we simply don't draw a dot. No crash, no problem.
        guard let wireEngine = self.wireEngine,
              let symbolNode = self.parent as? SymbolNode,
              let vertexID = wireEngine.findVertex(ownedBy: symbolNode.instance.id, pinID: self.pin.id)
        else {
            return primitives
        }

        let wireCount = wireEngine.adjacency[vertexID]?.count ?? 0

        if wireCount > 1 {
            let dotPath = CGPath(ellipseIn: CGRect(x: -2, y: -2, width: 4, height: 4), transform: nil)
            let dotPrimitive = DrawingPrimitive.fill(path: dotPath, color: NSColor.controlAccentColor.cgColor)
            primitives.append(dotPrimitive)
        }

        return primitives
    }

    override func makeHaloPath() -> CGPath? {
        return pin.makeHaloPath()
    }


    // ... (hitTest method remains the same) ...
    override func hitTest(_ point: CGPoint, tolerance: CGFloat) -> CanvasHitTarget? {
          let inflatedTolerance = tolerance * 2.0
          if CGRect(x: -pin.endpointRadius, y: -pin.endpointRadius, width: pin.endpointRadius * 2, height: pin.endpointRadius * 2).insetBy(dx: -tolerance, dy: -tolerance).contains(point) {
              return CanvasHitTarget(node: self, partIdentifier: Part.endpoint, position: self.convert(.zero, to: nil))
          }
          if pin.showNumber {
              let numberPath = pin.numberLayout()
              if numberPath.contains(point) || numberPath.copy(strokingWithWidth: inflatedTolerance, lineCap: .round, lineJoin: .round, miterLimit: 1).contains(point) {
                  return CanvasHitTarget(node: self, partIdentifier: Part.numberLabel, position: self.convert(point, to: nil))
              }
          }
          if pin.showLabel && !pin.name.isEmpty {
              let labelPath = pin.labelLayout()
              if labelPath.contains(point) || labelPath.copy(strokingWithWidth: inflatedTolerance, lineCap: .round, lineJoin: .round, miterLimit: 1).contains(point) {
                  return CanvasHitTarget(node: self, partIdentifier: Part.nameLabel, position: self.convert(point, to: nil))
              }
          }
          let legPath = CGMutablePath()
          legPath.move(to: self.pin.localLegStart)
          legPath.addLine(to: .zero)
          if legPath.copy(strokingWithWidth: inflatedTolerance, lineCap: .round, lineJoin: .round, miterLimit: 1).contains(point) {
              return CanvasHitTarget(node: self, partIdentifier: Part.body, position: self.convert(point, to: nil))
          }
          return nil
      }
}
