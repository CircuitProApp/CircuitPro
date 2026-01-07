import AppKit

final class ConnectionDebugRenderLayer: RenderLayer {
    private let contentLayer = CALayer()

    func install(on hostLayer: CALayer) {
        hostLayer.addSublayer(contentLayer)
    }

    func update(using context: RenderContext) {
        contentLayer.frame = context.hostViewBounds
        contentLayer.sublayers?.forEach { $0.removeFromSuperlayer() }

        guard let engine = context.connectionEngine else { return }

        let input = ConnectionInput.edges(
            anchors: context.connectionAnchors,
            edges: context.connectionEdges
        )
        let routingContext = ConnectionRoutingContext { point in
            context.snapProvider.snap(point: point, context: context)
        }
        let routes = engine.routes(from: input, context: routingContext)

        let mergedSegments = mergeSegments(
            from: Array(routes.values),
            magnification: context.magnification
        )
        let scale = 1.0 / max(context.magnification, .ulpOfOne)

        for segment in mergedSegments {
            let path = CGMutablePath()
            path.move(to: segment.start)
            path.addLine(to: segment.end)

            let shape = CAShapeLayer()
            shape.path = path
            shape.strokeColor = color(for: segment).cgColor
            shape.lineWidth = 3.0 * scale
            shape.lineCap = .round
            shape.fillColor = nil
            contentLayer.addSublayer(shape)
        }

        for anchor in context.connectionAnchors {
            let dot = CAShapeLayer()
            let rect = CGRect(x: anchor.position.x - 3, y: anchor.position.y - 3, width: 6, height: 6)
            dot.path = CGPath(ellipseIn: rect, transform: nil)
            dot.fillColor = NSColor.systemBlue.cgColor
            contentLayer.addSublayer(dot)
        }
    }

    private struct MergedSegment {
        let start: CGPoint
        let end: CGPoint
    }

    private enum Orientation: Hashable {
        case horizontal
        case vertical
    }

    private struct Segment {
        let orientation: Orientation
        let fixed: CGFloat
        var min: CGFloat
        var max: CGFloat
    }

    private func mergeSegments(
        from routes: [any ConnectionRoute],
        magnification: CGFloat
    ) -> [MergedSegment] {
        let epsilon = max(0.5 / max(magnification, 0.0001), 0.0001)
        var segments: [Segment] = []

        for route in routes {
            guard let manhattan = route as? ManhattanRoute else { continue }
            let points = manhattan.points
            guard points.count >= 2 else { continue }

            for index in 0..<(points.count - 1) {
                let start = points[index]
                let end = points[index + 1]
                let dx = end.x - start.x
                let dy = end.y - start.y

                if abs(dx) <= epsilon && abs(dy) <= epsilon {
                    continue
                } else if abs(dx) <= epsilon {
                    let minY = min(start.y, end.y)
                    let maxY = max(start.y, end.y)
                    segments.append(
                        Segment(orientation: .vertical, fixed: start.x, min: minY, max: maxY)
                    )
                } else if abs(dy) <= epsilon {
                    let minX = min(start.x, end.x)
                    let maxX = max(start.x, end.x)
                    segments.append(
                        Segment(orientation: .horizontal, fixed: start.y, min: minX, max: maxX)
                    )
                }
            }
        }

        if segments.isEmpty {
            return []
        }

        struct SegmentKey: Hashable {
            let orientation: Orientation
            let bucket: Int
        }

        func bucket(for value: CGFloat) -> Int {
            Int((value / epsilon).rounded())
        }

        var grouped: [SegmentKey: [Segment]] = [:]
        for segment in segments {
            let key = SegmentKey(
                orientation: segment.orientation,
                bucket: bucket(for: segment.fixed)
            )
            grouped[key, default: []].append(segment)
        }

        var merged: [Segment] = []
        merged.reserveCapacity(segments.count)

        for group in grouped.values {
            let sorted = group.sorted { $0.min < $1.min }
            guard var current = sorted.first else { continue }

            for segment in sorted.dropFirst() {
                if segment.min <= current.max + epsilon {
                    current.max = max(current.max, segment.max)
                } else {
                    merged.append(current)
                    current = segment
                }
            }
            merged.append(current)
        }

        return merged.map { segment in
            switch segment.orientation {
            case .horizontal:
                return MergedSegment(
                    start: CGPoint(x: segment.min, y: segment.fixed),
                    end: CGPoint(x: segment.max, y: segment.fixed)
                )
            case .vertical:
                return MergedSegment(
                    start: CGPoint(x: segment.fixed, y: segment.min),
                    end: CGPoint(x: segment.fixed, y: segment.max)
                )
            }
        }
    }

    private func color(for segment: MergedSegment) -> NSColor {
        var hasher = Hasher()
        hasher.combine(segment.start.x)
        hasher.combine(segment.start.y)
        hasher.combine(segment.end.x)
        hasher.combine(segment.end.y)
        let value = hasher.finalize()
        let hue = CGFloat(abs(value == Int.min ? 0 : value) % 360) / 360.0
        return NSColor(calibratedHue: hue, saturation: 0.7, brightness: 0.9, alpha: 0.6)
    }
}
