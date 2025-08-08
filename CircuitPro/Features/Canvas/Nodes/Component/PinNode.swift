import AppKit
import Observation

/// A scene graph node that represents a `Pin` data model on the canvas.
///
/// This class is the `CanvasElement`. It wraps a `Pin` struct and is responsible for
/// all drawing and hit-testing logic by using the geometry calculations defined
/// in the `Pin+Geometry` extension.
@Observable
class PinNode: BaseNode {
    
    // MARK: - Properties
    
    var pin: Pin {
        didSet {
            onNeedsRedraw?()
        }
    }
    
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
    
    init(pin: Pin) {
        self.pin = pin
        super.init(id: pin.id)
    }
    
    // MARK: - Drawable Conformance
    
    /// Delegates drawing command generation to the underlying Pin model.
    override func makeDrawingPrimitives() -> [DrawingPrimitive] {
        return pin.makeDrawingPrimitives()
    }
    
    /// Delegates halo path generation to the underlying Pin model.
    override func makeHaloPath() -> CGPath? {
        return pin.makeHaloPath()
    }
    
    // MARK: - Hittable Conformance
    
    override func hitTest(_ point: CGPoint, tolerance: CGFloat) -> CanvasHitTarget? {
          let inflatedTolerance = tolerance * 2.0
          
          // --- Test specific parts first, in order of importance ---
          
          // Priority 1: Endpoint
          let endpointRect = CGRect(x: -pin.endpointRadius, y: -pin.endpointRadius, width: pin.endpointRadius * 2, height: pin.endpointRadius * 2)
          if endpointRect.insetBy(dx: -tolerance, dy: -tolerance).contains(point) {
              return CanvasHitTarget(node: self, partIdentifier: Part.endpoint, position: self.convert(.zero, to: nil))
          }
          
          // Priority 2: Text Labels (using their vector paths)
          if pin.showNumber {
              let numberPath = pin.numberLayout() // This returns a CGPath
              if numberPath.contains(point) || numberPath.copy(strokingWithWidth: inflatedTolerance, lineCap: .round, lineJoin: .round, miterLimit: 1).contains(point) {
                  return CanvasHitTarget(node: self, partIdentifier: Part.numberLabel, position: self.convert(point, to: nil))
              }
          }
          
          if pin.showLabel && !pin.name.isEmpty {
              let labelPath = pin.labelLayout() // This returns a CGPath
              if labelPath.contains(point) || labelPath.copy(strokingWithWidth: inflatedTolerance, lineCap: .round, lineJoin: .round, miterLimit: 1).contains(point) {
                  return CanvasHitTarget(node: self, partIdentifier: Part.nameLabel, position: self.convert(point, to: nil))
              }
          }
          
          // Priority 3: Pin Leg
          let legPath = CGMutablePath()
          legPath.move(to: self.pin.localLegStart)
          legPath.addLine(to: .zero)
          if legPath.copy(strokingWithWidth: inflatedTolerance, lineCap: .round, lineJoin: .round, miterLimit: 1).contains(point) {
              return CanvasHitTarget(node: self, partIdentifier: Part.body, position: self.convert(point, to: nil))
          }

          // If nothing specific was hit, return nil.
          return nil
      }
}
