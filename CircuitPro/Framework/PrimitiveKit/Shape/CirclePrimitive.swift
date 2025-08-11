import CoreGraphics

public struct CirclePrimitive: Codable, Hashable {
    public var radius: CGFloat

    public init(radius: CGFloat) {
        self.radius = radius
    }
}
