import AppKit

struct CKLine: CKView {
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

}

extension CKLine: CKNodeView {
    func makeNode(in context: RenderContext) -> CKRenderNode? {
        CKRenderNode(
            geometry: .path { _ in
                let startPoint: CGPoint
                let endPoint: CGPoint

                if let start = start, let end = end {
                    startPoint = start
                    endPoint = end
                } else {
                    let half = (length ?? 0) * 0.5
                    let resolvedDirection = direction ?? .horizontal

                    switch resolvedDirection {
                    case .horizontal:
                        startPoint = CGPoint(x: -half, y: 0)
                        endPoint = CGPoint(x: half, y: 0)
                    case .vertical:
                        startPoint = CGPoint(x: 0, y: -half)
                        endPoint = CGPoint(x: 0, y: half)
                    }
                }

                let path = CGMutablePath()
                path.move(to: startPoint)
                path.addLine(to: endPoint)
                return path
            }
        )
    }
}
