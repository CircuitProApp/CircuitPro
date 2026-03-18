import Foundation

struct TraceAssignVertexLayersRule {
    func apply(to state: inout TraceNormalizationState) {
        let adjacency = buildAdjacency(from: state.links)

        for pointID in Array(state.typedPointsByID.keys) {
            guard let vertex = state.typedPointsByID[pointID] else { continue }
            let incidentLinks = (adjacency[pointID] ?? []).compactMap { linkID in
                state.links.first(where: { $0.id == linkID })
            }
            guard !incidentLinks.isEmpty else { continue }

            let grouped = Dictionary(grouping: incidentLinks, by: \.layerId)
            let sortedLayers = grouped.keys.sorted { $0.uuidString < $1.uuidString }
            guard let primaryLayer = preferredLayer(for: vertex, from: sortedLayers) else {
                continue
            }

            if vertex.layerId != primaryLayer {
                updateVertex(pointID, layerId: primaryLayer, state: &state)
            }

            if grouped.count <= 1 {
                continue
            }

            for layerId in sortedLayers where layerId != primaryLayer {
                let clone = TraceVertex(position: vertex.position, layerId: layerId)
                state.addedPoints.append(clone)
                state.typedPointsByID[clone.id] = clone
                state.pointsByID[clone.id] = clone.position
                state.pointsByObject[clone.id] = clone

                let rewireIDs = Set(grouped[layerId]?.map(\.id) ?? [])
                for index in state.links.indices where rewireIDs.contains(state.links[index].id) {
                    if state.links[index].startID == pointID {
                        state.links[index].startID = clone.id
                    }
                    if state.links[index].endID == pointID {
                        state.links[index].endID = clone.id
                    }
                }
            }
        }
    }

    private func buildAdjacency(from links: [TraceSegment]) -> [UUID: [UUID]] {
        var adjacency: [UUID: [UUID]] = [:]
        for link in links {
            adjacency[link.startID, default: []].append(link.id)
            adjacency[link.endID, default: []].append(link.id)
        }
        return adjacency
    }

    private func preferredLayer(
        for vertex: TraceVertex,
        from layers: [UUID]
    ) -> UUID? {
        if layers.contains(vertex.layerId) {
            return vertex.layerId
        }
        return layers.first
    }

    private func updateVertex(
        _ pointID: UUID,
        layerId: UUID,
        state: inout TraceNormalizationState
    ) {
        guard var vertex = state.typedPointsByID[pointID] else { return }
        vertex.layerId = layerId
        state.typedPointsByID[pointID] = vertex
        state.pointsByObject[pointID] = vertex
    }
}
