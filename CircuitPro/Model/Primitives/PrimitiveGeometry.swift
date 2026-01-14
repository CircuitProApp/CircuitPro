import CoreGraphics

enum PrimitiveGeometry {
    static func localPath(for primitive: AnyCanvasPrimitive) -> CGPath {
        switch primitive {
        case .line(let line):
            let halfLength = line.length / 2
            let localStart = CGPoint(x: -halfLength, y: 0)
            let localEnd = CGPoint(x: halfLength, y: 0)
            let path = CGMutablePath()
            path.move(to: localStart)
            path.addLine(to: localEnd)
            return path
        case .rectangle(let rectangle):
            let frame = CGRect(
                x: -rectangle.size.width * 0.5,
                y: -rectangle.size.height * 0.5,
                width: rectangle.size.width,
                height: rectangle.size.height
            )
            let path = CGMutablePath()
            let clampedCornerRadius = max(
                0,
                min(rectangle.cornerRadius, min(rectangle.size.width, rectangle.size.height) * 0.5)
            )
            path.addRoundedRect(
                in: frame,
                cornerWidth: clampedCornerRadius,
                cornerHeight: clampedCornerRadius
            )
            return path
        case .circle(let circle):
            let path = CGMutablePath()
            path.addArc(
                center: .zero,
                radius: circle.radius,
                startAngle: 0,
                endAngle: .pi * 2,
                clockwise: false
            )
            return path
        }
    }

    static func localBoundingBox(for primitive: AnyCanvasPrimitive) -> CGRect {
        var box = localPath(for: primitive).boundingBoxOfPath
        if !primitive.filled {
            let inset = -primitive.strokeWidth / 2
            box = box.insetBy(dx: inset, dy: inset)
        }
        return box
    }
}
