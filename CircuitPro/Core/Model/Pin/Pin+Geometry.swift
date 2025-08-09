import AppKit
import CoreText

extension Pin {

    // MARK: - Core Geometric Properties (Local Space)

    var length: CGFloat {
        switch lengthType {
        case .short: return 20
        case .long:  return 30
        }
    }

    var endpointRadius: CGFloat { 4.0 }

    /// The calculated start position of the pin's leg in its local coordinate space.
    /// The end of the leg is always at the local origin (0,0).
    var localLegStart: CGPoint {
        let dir = cardinalRotation.direction
        return CGPoint(x: dir.x * length, y: dir.y * length)
    }

    // MARK: - Drawable Conformance

    /// Generates the high-level drawing commands for the pin.
    func makeDrawingPrimitives() -> [DrawingPrimitive] {
         let pinColor = NSColor.systemBlue
         var primitives: [DrawingPrimitive] = []

         // 1. Stroke the leg and endpoint
         let legPath = CGMutablePath()
         legPath.move(to: localLegStart)
         legPath.addLine(to: .zero)
         primitives.append(.stroke(path: legPath, color: pinColor.cgColor, lineWidth: 1.0))
         
         let endpointRect = CGRect(x: -endpointRadius, y: -endpointRadius, width: endpointRadius * 2, height: endpointRadius * 2)
         primitives.append(.stroke(path: CGPath(ellipseIn: endpointRect, transform: nil), color: pinColor.cgColor, lineWidth: 1.0))

         // 2. Fill the vector paths for the text
         if showNumber {
             let numberPath = numberLayout()
             primitives.append(.fill(path: numberPath, color: pinColor.cgColor))
         }

         if showLabel && !name.isEmpty {
             let labelPath = labelLayout()
             primitives.append(.fill(path: labelPath, color: pinColor.cgColor))
         }

         return primitives
     }

     func makeHaloPath() -> CGPath? {
         return calculateCompositePath()
     }
     
     // MARK: - Composite Path & Layout

     private func calculateCompositePath() -> CGPath {
         let outline = CGMutablePath()

         // 1. Add leg and circle paths
         let legPath = CGMutablePath()
         legPath.move(to: localLegStart)
         legPath.addLine(to: .zero)
         outline.addPath(legPath)
         
         let endpointRect = CGRect(x: -endpointRadius, y: -endpointRadius, width: endpointRadius * 2, height: endpointRadius * 2)
         outline.addPath(CGPath(ellipseIn: endpointRect, transform: nil))

         // 2. Add the final, transformed text paths. No need to "fatten" them separately.
         if showNumber {
             outline.addPath(numberLayout())
         }
         if showLabel && !name.isEmpty {
             outline.addPath(labelLayout())
         }
         
         return outline
     }

     // --- Text layout functions now return a final, transformed CGPath ---

     func labelLayout() -> CGPath {
         let font = NSFont.systemFont(ofSize: 10)
         let pad: CGFloat = 4
         
         let textPath = TextUtilities.path(for: name, font: font)
         let bounds = textPath.boundingBoxOfPath
         
         let (targetPoint, anchorPoint): (CGPoint, CGPoint)

         switch cardinalRotation {
         case .west:
             targetPoint = CGPoint(x: localLegStart.x - pad, y: localLegStart.y)
             anchorPoint = CGPoint(x: bounds.maxX, y: bounds.midY)
         case .east:
             targetPoint = CGPoint(x: localLegStart.x + pad, y: localLegStart.y)
             anchorPoint = CGPoint(x: bounds.minX, y: bounds.midY)
         case .north:
             targetPoint = CGPoint(x: localLegStart.x, y: localLegStart.y + pad)
             anchorPoint = CGPoint(x: bounds.midX, y: bounds.minY)
         case .south:
             targetPoint = CGPoint(x: localLegStart.x, y: localLegStart.y - pad)
             anchorPoint = CGPoint(x: bounds.midX, y: bounds.maxY)
         default:
             targetPoint = CGPoint(x: localLegStart.x + pad, y: localLegStart.y)
             anchorPoint = CGPoint(x: bounds.minX, y: bounds.midY)
         }
         
         var transform = CGAffineTransform(translationX: targetPoint.x - anchorPoint.x, y: targetPoint.y - anchorPoint.y)
         return textPath.copy(using: &transform) ?? textPath
     }

     func numberLayout() -> CGPath {
         let font = NSFont.systemFont(ofSize: 9, weight: .medium)
         let pad: CGFloat = 5
         
         let textPath = TextUtilities.path(for: "\(number)", font: font)
         let bounds = textPath.boundingBoxOfPath
         
         let mid = CGPoint(x: localLegStart.x / 2, y: localLegStart.y / 2)
         let targetPoint: CGPoint

         switch cardinalRotation {
         case .north, .south:
             targetPoint = CGPoint(x: mid.x + pad, y: mid.y)
         default:
             targetPoint = CGPoint(x: mid.x, y: mid.y + pad)
         }
         
         let anchorPoint = CGPoint(x: bounds.midX, y: bounds.midY)
         var transform = CGAffineTransform(translationX: targetPoint.x - anchorPoint.x, y: targetPoint.y - anchorPoint.y)
         return textPath.copy(using: &transform) ?? textPath
     }
}
