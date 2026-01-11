import AppKit

struct CKLine: CKPathView {
    enum Direction {
        case horizontal
        case vertical
    }

    var length: CGFloat?
    var direction: Direction?
    var start: CGPoint?
    var end: CGPoint?

    init(length: CGFloat, direction: Direction) {
        self.length = length
        self.direction = direction
    }

    init(from start: CGPoint, to end: CGPoint) {
        self.start = start
        self.end = end
    }

    func path(in context: RenderContext, style: CKStyle) -> CGPath {
        let startPoint: CGPoint
        let endPoint: CGPoint

        if let start = start, let end = end {
            startPoint = start
            endPoint = end
        } else {
            let center = style.position ?? .zero
            let half = (length ?? 0) * 0.5
            let resolvedDirection = direction ?? .horizontal

            switch resolvedDirection {
            case .horizontal:
                startPoint = CGPoint(x: center.x - half, y: center.y)
                endPoint = CGPoint(x: center.x + half, y: center.y)
            case .vertical:
                startPoint = CGPoint(x: center.x, y: center.y - half)
                endPoint = CGPoint(x: center.x, y: center.y + half)
            }
        }

        let path = CGMutablePath()
        path.move(to: startPoint)
        path.addLine(to: endPoint)
        return path
    }
}
