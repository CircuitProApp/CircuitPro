import CoreGraphics

public struct LinePrimitive: Codable, Hashable {
    public var length: CGFloat

    public init(length: CGFloat) {
        self.length = length
    }
}
