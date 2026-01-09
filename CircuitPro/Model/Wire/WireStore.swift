import Foundation

struct WireStore: Codable {
    var points: [WireVertex]
    var links: [WireSegment]
}
