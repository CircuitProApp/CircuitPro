import Foundation
import CoreGraphics

// Represents a point that a wire segment can connect to.
// It's Codable so it can be saved to JSON.
enum AttachmentPoint: Codable, Hashable {
    // A connection to a specific pin on a specific component instance
    case pin(componentInstanceID: UUID, pinID: UUID)
    
    // A free-floating point in space, part of a larger wire or a junction
    case free(point: CGPoint)
}

// Represents a single segment of a wire.
struct WireSegment: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var start: AttachmentPoint
    var end: AttachmentPoint
}

// Represents a whole wire (or net), which is composed of multiple segments.
// This is the top-level object we'll save in the document.
struct Wire: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var segments: [WireSegment]
}
