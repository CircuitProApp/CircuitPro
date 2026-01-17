struct Trace: Codable, Hashable {
    var points: [TraceVertex]
    var links: [TraceSegment]

    init(points: [TraceVertex] = [], links: [TraceSegment] = []) {
        self.points = points
        self.links = links
    }
}
