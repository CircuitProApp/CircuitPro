import Foundation

// Represents a whole wire (or net), which is composed of multiple segments.
// This is the top-level object we'll save in the document.
struct Wire: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var segments: [WireSegment]

    // Compare by content, not by id
    static func == (lhs: Wire, rhs: Wire) -> Bool {
        // Compare segments as sets since order may vary
        Set(lhs.segments) == Set(rhs.segments)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(Set(segments))
    }
}
