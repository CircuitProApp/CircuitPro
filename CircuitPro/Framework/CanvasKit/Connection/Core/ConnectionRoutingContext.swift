import Foundation

/// Routing context for connection engines. Keep this domain-agnostic.
struct ConnectionRoutingContext {
    let snapPoint: (CGPoint) -> CGPoint

    init(snapPoint: @escaping (CGPoint) -> CGPoint = { $0 }) {
        self.snapPoint = snapPoint
    }
}
