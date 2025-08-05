//
//  PinNode.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/5/25.
//

import AppKit

/// A scene graph node that represents a `Pin` data model on the canvas.
///
/// This class is the `CanvasElement`. It wraps a `Pin` struct and is responsible for
/// all drawing and hit-testing logic by using the geometry calculations defined
/// in the `Pin+Geometry` extension.
class PinNode: BaseNode {

    // MARK: - Properties

    /// The underlying data model for this node.
    var pin: Pin

    /// Defines the distinct, hittable parts of a PinNode for rich interaction.
    enum Part: Hashable {
        case endpoint
        case body
        case nameLabel
        case numberLabel
    }

    // MARK: - Overridden Scene Graph Properties

    override var position: CGPoint {
        get { pin.position }
        set { pin.position = newValue }
    }

    override var rotation: CGFloat {
        get { pin.rotation }
        set { pin.rotation = newValue }
    }
    
    // MARK: - Initialization

    init(pin: Pin) {
        self.pin = pin
        // Pass the pin's ID to the superclass to ensure the node and the model share an identity.
        super.init(id: pin.id)
    }

    // MARK: - Drawable Conformance

    override func makeBodyParameters() -> [DrawingParameters] {
          var params: [DrawingParameters] = []
          let pinColor = NSColor.systemBlue.cgColor

          // 1. Draw the pin leg (now a local path)
          let legPath = CGMutablePath()
          legPath.move(to: pin.localLegStart)
          legPath.addLine(to: .zero) // End at the local origin
          params.append(DrawingParameters(path: legPath, lineWidth: 1, strokeColor: pinColor))
          
          // 2. Draw the pin endpoint (now a local path)
          let endpointRect = CGRect(x: -pin.endpointRadius, y: -pin.endpointRadius, width: pin.endpointRadius * 2, height: pin.endpointRadius * 2)
          params.append(DrawingParameters(path: CGPath(ellipseIn: endpointRect, transform: nil), lineWidth: 1, strokeColor: pinColor))
          
          // 3 & 4. Text layout functions are already local-space aware. No changes needed here.
          if pin.showNumber {
              var (path, transform) = pin.numberLayout()
              if let finalPath = path.copy(using: &transform) {
                  params.append(DrawingParameters(path: finalPath, lineWidth: 0, fillColor: pinColor))
              }
          }
          
          if pin.showLabel && !pin.name.isEmpty {
              var (path, transform) = pin.labelLayout()
              if let finalPath = path.copy(using: &transform) {
                  params.append(DrawingParameters(path: finalPath, lineWidth: 0, fillColor: pinColor))
              }
          }
          
          return params
      }

      override func makeHaloPath() -> CGPath? {
          return pin.calculateCompositePath()
      }

      // MARK: - Hittable Conformance (Now Using Local Geometry)

      override func hitTest(_ point: CGPoint, tolerance: CGFloat) -> CanvasHitTarget? {
          // The `point` received here is a local coordinate, which is what we need.
          
          // 1. Test Endpoint in local space.
          let endpointRect = CGRect(x: -pin.endpointRadius, y: -pin.endpointRadius, width: pin.endpointRadius*2, height: pin.endpointRadius*2)
          if endpointRect.insetBy(dx: -tolerance, dy: -tolerance).contains(point) {
              return CanvasHitTarget(
                  node: self,
                  partIdentifier: Part.endpoint,
                  // The CANONICAL position is this node's world location.
                  position: self.convert(.zero, to: nil)
              )
          }
          
          // 2. Test Full Body in local space.
          let bodyPath = pin.calculateCompositePath()
          let hitArea = bodyPath.copy(strokingWithWidth: tolerance * 2, lineCap: .round, lineJoin: .round, miterLimit: 1)
          
          if hitArea.contains(point) {
              return CanvasHitTarget(
                  node: self,
                  partIdentifier: Part.body,
                  // The HIT position is the clicked point, converted to world space.
                  position: self.convert(point, to: nil)
              )
          }
          
          return nil
      }
}
