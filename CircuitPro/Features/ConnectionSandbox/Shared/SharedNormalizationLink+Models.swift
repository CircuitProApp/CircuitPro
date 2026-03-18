import CoreGraphics
import Foundation

extension WireSegment: SharedNormalizationLink {
    var normalizationMetadata: EmptyLinkMetadata { EmptyLinkMetadata() }

    init(
        id: UUID,
        startID: UUID,
        endID: UUID,
        normalizationMetadata: EmptyLinkMetadata
    ) {
        self.init(id: id, startID: startID, endID: endID)
    }
}

extension TraceSegment: SharedNormalizationLink {
    struct Metadata: Hashable {
        let width: CGFloat
        let layerId: UUID
    }

    var normalizationMetadata: Metadata {
        Metadata(width: width, layerId: layerId)
    }

    init(
        id: UUID,
        startID: UUID,
        endID: UUID,
        normalizationMetadata: Metadata
    ) {
        self.init(
            id: id,
            startID: startID,
            endID: endID,
            width: normalizationMetadata.width,
            layerId: normalizationMetadata.layerId
        )
    }
}
