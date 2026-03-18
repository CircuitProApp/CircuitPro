import Foundation

struct EmptyLinkMetadata: Hashable {}

protocol SharedNormalizationLink: ConnectionLink {
    associatedtype Metadata: Hashable

    var startID: UUID { get set }
    var endID: UUID { get set }
    var normalizationMetadata: Metadata { get }

    init(
        id: UUID,
        startID: UUID,
        endID: UUID,
        normalizationMetadata: Metadata
    )
}
