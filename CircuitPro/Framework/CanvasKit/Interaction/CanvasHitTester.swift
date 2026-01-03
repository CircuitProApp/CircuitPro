//
//  CanvasHitTester.swift
//  CircuitPro
//
//  Created by Codex on 12/31/25.
//

import CoreGraphics
import AppKit

struct CanvasHitTester {
    private struct HitCandidate {
        let id: UUID
        let priority: Int
        let area: CGFloat
    }

    func hitTest(point: CGPoint, context: RenderContext) -> UUID? {
        let tolerance = 5.0 / context.magnification
        var best: HitCandidate?

        for item in context.items {
            if let component = item as? ComponentInstance {
                evaluateComponentHits(
                    component,
                    at: point,
                    tolerance: tolerance,
                    context: context,
                    best: &best
                )
                continue
            }

            if let primitive = item as? AnyCanvasPrimitive {
                if primitive.hitTest(point: point, tolerance: tolerance) {
                    considerHit(
                        id: primitive.id,
                        priority: 1,
                        area: primitive.boundingBox.width * primitive.boundingBox.height,
                        best: &best
                    )
                }
                continue
            }

            if let pin = item as? Pin {
                if hitTest(pin: pin, at: point, tolerance: tolerance) {
                    let area = pinBounds(pin: pin).width * pinBounds(pin: pin).height
                    considerHit(id: pin.id, priority: 10, area: area, best: &best)
                }
                continue
            }

            if let pad = item as? Pad {
                if hitTest(pad: pad, at: point, tolerance: tolerance) {
                    let bounds = padBounds(pad: pad)
                    considerHit(id: pad.id, priority: 10, area: bounds.width * bounds.height, best: &best)
                }
                continue
            }

            if let text = item as? CircuitText.Definition {
                if hitTest(text: text, displayText: displayText(for: text, context: context), at: point, tolerance: tolerance) {
                    let bounds = textBounds(text: text, displayText: displayText(for: text, context: context))
                    considerHit(id: text.id, priority: 8, area: bounds.width * bounds.height, best: &best)
                }
                continue
            }

            if let hitTestable = item as? HitTestable {
                if hitTestable.hitTest(point: point, tolerance: tolerance) {
                    let area = (item as? Bounded).map { $0.boundingBox.width * $0.boundingBox.height } ?? 0
                    considerHit(
                        id: item.id,
                        priority: hitTestable.hitTestPriority,
                        area: area,
                        best: &best
                    )
                }
                continue
            }
        }

        return best?.id
    }

    func hitTestAll(in rect: CGRect, context: RenderContext) -> [UUID] {
        var hits = Set<UUID>()

        for item in context.items {
            if let component = item as? ComponentInstance {
                let bodyBounds = componentBodyBounds(component, context: context)
                if rect.intersects(bodyBounds) {
                    hits.insert(component.id)
                }
                for text in componentTexts(component, context: context) {
                    let bounds = textBounds(text: text.text, displayText: text.displayText, ownerTransform: text.ownerTransform, ownerRotation: text.ownerRotation)
                    if rect.intersects(bounds) {
                        hits.insert(text.text.id)
                    }
                }
                continue
            }

            if let primitive = item as? AnyCanvasPrimitive {
                if rect.intersects(primitive.boundingBox) {
                    hits.insert(primitive.id)
                }
                continue
            }

            if let pin = item as? Pin {
                if rect.intersects(pinBounds(pin: pin)) {
                    hits.insert(pin.id)
                }
                continue
            }

            if let pad = item as? Pad {
                if rect.intersects(padBounds(pad: pad)) {
                    hits.insert(pad.id)
                }
                continue
            }

            if let text = item as? CircuitText.Definition {
                let bounds = textBounds(text: text, displayText: displayText(for: text, context: context))
                if rect.intersects(bounds) {
                    hits.insert(text.id)
                }
                continue
            }

            if let bounded = item as? Bounded {
                if rect.intersects(bounded.boundingBox) {
                    hits.insert(item.id)
                }
                continue
            }
        }

        return Array(hits)
    }

    private func considerHit(
        id: UUID,
        priority: Int,
        area: CGFloat,
        best: inout HitCandidate?
    ) {
        considerHit(candidate: HitCandidate(id: id, priority: priority, area: area), best: &best)
    }

    private func considerHit(candidate: HitCandidate, best: inout HitCandidate?) {
        guard let current = best else {
            best = candidate
            return
        }
        if candidate.priority > current.priority ||
            (candidate.priority == current.priority && candidate.area < current.area) {
            best = candidate
        }
    }

    private func evaluateComponentHits(
        _ component: ComponentInstance,
        at point: CGPoint,
        tolerance: CGFloat,
        context: RenderContext,
        best: inout HitCandidate?
    ) {
        if let textHit = componentTextHit(component, at: point, tolerance: tolerance, context: context) {
            considerHit(candidate: textHit, best: &best)
        }

        if componentBodyHit(component, at: point, tolerance: tolerance, context: context) {
            let bounds = componentBodyBounds(component, context: context)
            considerHit(
                id: component.id,
                priority: 5,
                area: bounds.width * bounds.height,
                best: &best
            )
        }
    }

    private func componentBodyHit(
        _ component: ComponentInstance,
        at point: CGPoint,
        tolerance: CGFloat,
        context: RenderContext
    ) -> Bool {
        let target = context.environment.textTarget
        switch target {
        case .symbol:
            guard let symbolDef = component.symbolInstance.definition else { return false }
            let ownerTransform = CGAffineTransform(
                translationX: component.symbolInstance.position.x,
                y: component.symbolInstance.position.y
            )
            .rotated(by: component.symbolInstance.rotation)
            let localPoint = point.applying(ownerTransform.inverted())
            for primitive in symbolDef.primitives {
                let primTransform = CGAffineTransform(
                    translationX: primitive.position.x, y: primitive.position.y
                ).rotated(by: primitive.rotation)
                let primLocal = localPoint.applying(primTransform.inverted())
                if primitive.hitTest(primLocal, tolerance: tolerance) != nil {
                    return true
                }
            }
            for pin in symbolDef.pins {
                if hitTest(pin: pin, at: localPoint, tolerance: tolerance) {
                    return true
                }
            }
            return false
        case .footprint:
            guard let footprint = component.footprintInstance,
                  case .placed = footprint.placement,
                  let definition = footprint.definition
            else { return false }
            let ownerTransform = CGAffineTransform(
                translationX: footprint.position.x,
                y: footprint.position.y
            ).rotated(by: footprint.rotation)
            let localPoint = point.applying(ownerTransform.inverted())
            for primitive in definition.primitives {
                let primTransform = CGAffineTransform(
                    translationX: primitive.position.x, y: primitive.position.y
                ).rotated(by: primitive.rotation)
                let primLocal = localPoint.applying(primTransform.inverted())
                if primitive.hitTest(primLocal, tolerance: tolerance) != nil {
                    return true
                }
            }
            for pad in definition.pads {
                if hitTest(pad: pad, at: localPoint, tolerance: tolerance) {
                    return true
                }
            }
            return false
        }
    }

    private func componentBodyBounds(
        _ component: ComponentInstance,
        context: RenderContext
    ) -> CGRect {
        let target = context.environment.textTarget
        switch target {
        case .symbol:
            guard let symbolDef = component.symbolInstance.definition else { return .null }
            let ownerTransform = CGAffineTransform(
                translationX: component.symbolInstance.position.x,
                y: component.symbolInstance.position.y
            )
            .rotated(by: component.symbolInstance.rotation)
            var combined = CGRect.null
            for primitive in symbolDef.primitives {
                var box = primitive.boundingBox
                let primTransform = CGAffineTransform(
                    translationX: primitive.position.x, y: primitive.position.y
                ).rotated(by: primitive.rotation)
                box = box.applying(primTransform)
                combined = combined.union(box)
            }
            for pin in symbolDef.pins {
                combined = combined.union(pinBounds(pin: pin))
            }
            return combined.isNull ? .null : combined.applying(ownerTransform)
        case .footprint:
            guard let footprint = component.footprintInstance,
                  case .placed = footprint.placement,
                  let definition = footprint.definition
            else { return .null }
            let ownerTransform = CGAffineTransform(
                translationX: footprint.position.x,
                y: footprint.position.y
            ).rotated(by: footprint.rotation)
            var combined = CGRect.null
            for primitive in definition.primitives {
                var box = primitive.boundingBox
                let primTransform = CGAffineTransform(
                    translationX: primitive.position.x, y: primitive.position.y
                ).rotated(by: primitive.rotation)
                box = box.applying(primTransform)
                combined = combined.union(box)
            }
            for pad in definition.pads {
                combined = combined.union(padBounds(pad: pad))
            }
            return combined.isNull ? .null : combined.applying(ownerTransform)
        }
    }

    private func componentTextHit(
        _ component: ComponentInstance,
        at point: CGPoint,
        tolerance: CGFloat,
        context: RenderContext
    ) -> HitCandidate? {
        for text in componentTexts(component, context: context) {
            if hitTest(
                text: text.text,
                displayText: text.displayText,
                ownerTransform: text.ownerTransform,
                ownerRotation: text.ownerRotation,
                at: point,
                tolerance: tolerance
            ) {
                let bounds = textBounds(
                    text: text.text,
                    displayText: text.displayText,
                    ownerTransform: text.ownerTransform,
                    ownerRotation: text.ownerRotation
                )
                return HitCandidate(
                    id: text.text.id,
                    priority: 10,
                    area: bounds.width * bounds.height
                )
            }
        }
        return nil
    }

    private struct ComponentTextEntry {
        let text: CircuitText.Resolved
        let displayText: String
        let ownerTransform: CGAffineTransform
        let ownerRotation: CGFloat
    }

    private func componentTexts(
        _ component: ComponentInstance,
        context: RenderContext
    ) -> [ComponentTextEntry] {
        let target = context.environment.textTarget
        let ownerTransform: CGAffineTransform
        let ownerRotation: CGFloat
        let resolvedItems: [CircuitText.Resolved]

        switch target {
        case .symbol:
            ownerTransform = CGAffineTransform(
                translationX: component.symbolInstance.position.x,
                y: component.symbolInstance.position.y
            ).rotated(by: component.symbolInstance.rotation)
            ownerRotation = component.symbolInstance.rotation
            resolvedItems = component.symbolInstance.resolvedItems
        case .footprint:
            guard let footprint = component.footprintInstance,
                  case .placed = footprint.placement
            else { return [] }
            ownerTransform = CGAffineTransform(
                translationX: footprint.position.x,
                y: footprint.position.y
            ).rotated(by: footprint.rotation)
            ownerRotation = footprint.rotation
            resolvedItems = footprint.resolvedItems
        }

        return resolvedItems.map { resolvedText in
            let display = displayText(for: resolvedText, component: component, target: target, context: context)
            return ComponentTextEntry(
                text: resolvedText,
                displayText: display,
                ownerTransform: ownerTransform,
                ownerRotation: ownerRotation
            )
        }
    }

    private func displayText(
        for text: CircuitText.Resolved,
        component: ComponentInstance,
        target: TextTarget,
        context: RenderContext
    ) -> String {
        if let resolver = context.environment.componentTextResolver {
            return resolver(text, component, target)
        }
        return displayText(for: text.content)
    }

    private func displayText(for text: CircuitText.Definition, context: RenderContext) -> String {
        if let resolver = context.environment.definitionTextResolver {
            return resolver(text)
        }
        return displayText(for: text.content)
    }

    private func displayText(for content: CircuitTextContent) -> String {
        switch content {
        case .static(let value):
            return value
        case .componentName:
            return "Name"
        case .componentReferenceDesignator:
            return "REF?"
        case .componentProperty(_, _):
            return ""
        }
    }

    private func hitTest(pin: Pin, at point: CGPoint, tolerance: CGFloat) -> Bool {
        let localPoint = point.applying(
            CGAffineTransform(translationX: pin.position.x, y: pin.position.y)
                .inverted()
        )
        guard let bodyPath = pin.makeHaloPath() else { return false }
        let hitArea = bodyPath.copy(
            strokingWithWidth: tolerance,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 1
        )
        return hitArea.contains(localPoint) || bodyPath.contains(localPoint)
    }

    private func pinBounds(pin: Pin) -> CGRect {
        let local = pin.makeHaloPath()?.boundingBoxOfPath ?? .null
        guard !local.isNull else { return .null }
        let transform = CGAffineTransform(translationX: pin.position.x, y: pin.position.y)
        return local.applying(transform)
    }

    private func hitTest(pad: Pad, at point: CGPoint, tolerance: CGFloat) -> Bool {
        let localPoint = point.applying(
            CGAffineTransform(translationX: pad.position.x, y: pad.position.y)
                .rotated(by: pad.rotation)
                .inverted()
        )
        let bodyPath = pad.calculateCompositePath()
        let hitArea = bodyPath.copy(
            strokingWithWidth: tolerance,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 1
        )
        return hitArea.contains(localPoint) || bodyPath.contains(localPoint)
    }

    private func padBounds(pad: Pad) -> CGRect {
        let local = pad.calculateCompositePath().boundingBoxOfPath
        guard !local.isNull else { return .null }
        let transform = CGAffineTransform(translationX: pad.position.x, y: pad.position.y)
            .rotated(by: pad.rotation)
        return local.applying(transform)
    }

    private func hitTest(
        text: CircuitText.Definition,
        displayText: String,
        at point: CGPoint,
        tolerance: CGFloat
    ) -> Bool {
        hitTest(
            text: text,
            displayText: displayText,
            ownerTransform: .identity,
            ownerRotation: 0,
            at: point,
            tolerance: tolerance
        )
    }

    private func hitTest(
        text: CircuitText.Resolved,
        displayText: String,
        ownerTransform: CGAffineTransform,
        ownerRotation: CGFloat,
        at point: CGPoint,
        tolerance: CGFloat
    ) -> Bool {
        let path = textPath(
            displayText: displayText,
            font: text.font.nsFont,
            anchor: text.anchor,
            relativePosition: text.relativePosition,
            anchorPosition: text.anchorPosition,
            textRotation: text.cardinalRotation.radians,
            ownerTransform: ownerTransform,
            ownerRotation: ownerRotation
        )
        let hitArea = path.copy(
            strokingWithWidth: tolerance * 2,
            lineCap: CGLineCap.round,
            lineJoin: CGLineJoin.round,
            miterLimit: 10
        )
        return path.contains(point) || hitArea.contains(point)
    }

    private func textBounds(
        text: CircuitText.Definition,
        displayText: String
    ) -> CGRect {
        textBounds(
            text: text,
            displayText: displayText,
            ownerTransform: .identity,
            ownerRotation: 0
        )
    }

    private func textBounds(
        text: CircuitText.Resolved,
        displayText: String,
        ownerTransform: CGAffineTransform,
        ownerRotation: CGFloat
    ) -> CGRect {
        let path = textPath(
            displayText: displayText,
            font: text.font.nsFont,
            anchor: text.anchor,
            relativePosition: text.relativePosition,
            anchorPosition: text.anchorPosition,
            textRotation: text.cardinalRotation.radians,
            ownerTransform: ownerTransform,
            ownerRotation: ownerRotation
        )
        return path.boundingBoxOfPath
    }

    private func hitTest(
        text: CircuitText.Definition,
        displayText: String,
        ownerTransform: CGAffineTransform,
        ownerRotation: CGFloat,
        at point: CGPoint,
        tolerance: CGFloat
    ) -> Bool {
        let path = textPath(
            displayText: displayText,
            font: text.font.nsFont,
            anchor: text.anchor,
            relativePosition: text.relativePosition,
            anchorPosition: text.anchorPosition,
            textRotation: text.cardinalRotation.radians,
            ownerTransform: ownerTransform,
            ownerRotation: ownerRotation
        )
        let hitArea = path.copy(
            strokingWithWidth: tolerance * 2,
            lineCap: CGLineCap.round,
            lineJoin: CGLineJoin.round,
            miterLimit: 10
        )
        return path.contains(point) || hitArea.contains(point)
    }

    private func textBounds(
        text: CircuitText.Definition,
        displayText: String,
        ownerTransform: CGAffineTransform,
        ownerRotation: CGFloat
    ) -> CGRect {
        let path = textPath(
            displayText: displayText,
            font: text.font.nsFont,
            anchor: text.anchor,
            relativePosition: text.relativePosition,
            anchorPosition: text.anchorPosition,
            textRotation: text.cardinalRotation.radians,
            ownerTransform: ownerTransform,
            ownerRotation: ownerRotation
        )
        return path.boundingBoxOfPath
    }

    private func textPath(
        displayText: String,
        font: AppKit.NSFont,
        anchor: TextAnchor,
        relativePosition: CGPoint,
        anchorPosition: CGPoint,
        textRotation: CGFloat,
        ownerTransform: CGAffineTransform,
        ownerRotation: CGFloat
    ) -> CGPath {
        CanvasTextGeometry.worldPath(
            for: displayText,
            font: font,
            anchor: anchor,
            relativePosition: relativePosition,
            anchorPosition: anchorPosition,
            textRotation: textRotation,
            ownerTransform: ownerTransform,
            ownerRotation: ownerRotation
        )
    }
}
