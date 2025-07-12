import Foundation

/// The type of vertex that was hit.
public enum VertexType {
    /// An endpoint of a connection.
    case endpoint
    /// A corner in a connection.
    case corner
    /// A junction where multiple connections meet.
    case junction
}
