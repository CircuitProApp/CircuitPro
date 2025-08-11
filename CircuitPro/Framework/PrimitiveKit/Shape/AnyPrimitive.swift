import Foundation

public enum AnyPrimitive: Codable, Hashable {
    case line(LinePrimitive)
    case rectangle(RectanglePrimitive)
    case circle(CirclePrimitive)
}
