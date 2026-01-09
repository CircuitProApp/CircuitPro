import Foundation

struct Wire: Codable, Hashable {
    var points: [WireVertex]
    var links: [WireSegment]

    init(points: [WireVertex] = [], links: [WireSegment] = []) {
        self.points = points
        self.links = links
    }
}
