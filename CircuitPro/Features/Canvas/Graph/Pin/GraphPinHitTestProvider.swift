//
//  GraphPinHitTestProvider.swift
//  CircuitPro
//
//  Created by Codex on 9/22/25.
//

import CoreGraphics

struct GraphPinHitTestProvider: GraphHitTestProvider {
    func hitTest(point: CGPoint, tolerance: CGFloat, graph: CanvasGraph, context: RenderContext) -> GraphHitCandidate? {
        var best: GraphHitCandidate?

        for (id, component) in graph.components(GraphPinComponent.self) {
            if !component.isSelectable, context.selectedTool is CursorTool { continue }
            let localPoint = point.applying(component.worldTransform.inverted())
            if isHit(point: localPoint, pin: component.pin, tolerance: tolerance) {
                let bounds = component.pin.makeHaloPath()?.boundingBoxOfPath ?? .zero
                let area = bounds.width * bounds.height
                let candidate = GraphHitCandidate(id: id, priority: 3, area: area)
                if let current = best {
                    if candidate.priority > current.priority ||
                        (candidate.priority == current.priority && candidate.area < current.area) {
                        best = candidate
                    }
                } else {
                    best = candidate
                }
            }
        }

        return best
    }

    func hitTestAll(in rect: CGRect, graph: CanvasGraph, context: RenderContext) -> [NodeID] {
        var hits = Set<NodeID>()
        let wantsSelectable = !(context.selectedTool is CursorTool)

        for (id, component) in graph.components(GraphPinComponent.self) {
            if !component.isSelectable, !wantsSelectable { continue }

            let bounds = component.pin.makeHaloPath()?.boundingBoxOfPath ?? .zero
            if bounds.isNull { continue }

            var transform = component.worldTransform
            let worldBounds = bounds.applying(transform)
            if rect.intersects(worldBounds) {
                hits.insert(id)
            }
        }

        return Array(hits)
    }

    private func isHit(point: CGPoint, pin: Pin, tolerance: CGFloat) -> Bool {
        let inflatedTolerance = tolerance * 2.0
        let endpointBounds = CGRect(
            x: -pin.endpointRadius,
            y: -pin.endpointRadius,
            width: pin.endpointRadius * 2,
            height: pin.endpointRadius * 2
        ).insetBy(dx: -tolerance, dy: -tolerance)

        if endpointBounds.contains(point) {
            return true
        }

        if pin.showNumber {
            let numberPath = pin.numberLayout()
            let stroked = numberPath.copy(
                strokingWithWidth: inflatedTolerance,
                lineCap: .round,
                lineJoin: .round,
                miterLimit: 1
            )
            if numberPath.contains(point) || stroked.contains(point) {
                return true
            }
        }

        if pin.showLabel && !pin.name.isEmpty {
            let labelPath = pin.labelLayout()
            let stroked = labelPath.copy(
                strokingWithWidth: inflatedTolerance,
                lineCap: .round,
                lineJoin: .round,
                miterLimit: 1
            )
            if labelPath.contains(point) || stroked.contains(point) {
                return true
            }
        }

        let legPath = CGMutablePath()
        legPath.move(to: pin.localLegStart)
        legPath.addLine(to: .zero)
        let legStroke = legPath.copy(
            strokingWithWidth: inflatedTolerance,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 1
        )
        return legStroke.contains(point)
    }
}
