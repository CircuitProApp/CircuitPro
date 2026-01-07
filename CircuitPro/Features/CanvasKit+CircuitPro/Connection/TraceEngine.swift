//
//  TraceEngine.swift
//  CircuitPro
//
//  Created by Codex on 9/22/25.
//

import Foundation

@MainActor
final class TraceEngine: TraceMetadataStore {
    var graph: ConnectionGraph
    let engine: GraphEngine
    private let geometry: GeometryPolicy
    private let edgePolicy: TraceEdgePolicy

    var edgeMetadata: [GraphEdge.ID: TraceEdgeMetadata] = [:]

    var onChange: (() -> Void)?

    init(graph: ConnectionGraph) {
        self.graph = graph
        self.geometry = OctilinearGeometry(step: 1)
        let policy = TraceEdgePolicy()
        self.edgePolicy = policy

        self.engine = GraphEngine(
            initialState: .empty,
            ruleset: OctilinearGraphRuleset(),
            geometry: geometry,
            edgePolicy: policy
        )

        policy.store = self

        engine.onChange = { [weak self] delta, final in
            self?.handleEngineDelta(delta, final: final)
        }
    }

    func addTrace(path: [CGPoint], width: CGFloat, layerId: UUID) {
        var tx = AddTraceTransaction(
            path: path,
            width: width,
            layerId: layerId,
            assignMetadata: { [weak self] edgeID, traceWidth, newLayerId in
                let metadata = TraceEdgeMetadata(width: traceWidth, layerId: newLayerId)
                self?.edgeMetadata[edgeID] = metadata
            }
        )
        _ = engine.execute(transaction: &tx)
    }

    func build(from segments: [TraceSegment]) {
        edgeMetadata.removeAll()
        var state = GraphState.empty
        let tol = geometry.epsilon

        for segment in segments {
            let startID = getOrCreateVertex(at: segment.start, in: &state, tolerance: tol)
            let endID = getOrCreateVertex(at: segment.end, in: &state, tolerance: tol)
            if let edge = state.addEdge(from: startID, to: endID) {
                edgeMetadata[edge.id] = TraceEdgeMetadata(width: segment.width, layerId: segment.layerId)
            }
        }

        engine.replaceState(state)
    }

    func toTraceSegments() -> [TraceSegment] {
        let state = engine.currentState
        var segments: [TraceSegment] = []
        segments.reserveCapacity(state.edges.count)

        for (edgeID, edge) in state.edges {
            guard let start = state.vertices[edge.start],
                  let end = state.vertices[edge.end],
                  let metadata = edgeMetadata[edgeID] else {
                continue
            }
            let segment = TraceSegment(
                start: start.point,
                end: end.point,
                width: metadata.width,
                layerId: metadata.layerId
            ).normalized()
            segments.append(segment)
        }

        return segments.sorted { $0.sortKey < $1.sortKey }
    }

    func delete(items: Set<UUID>) {
        var tx = DeleteItemsTransaction(items: items)
        _ = engine.execute(transaction: &tx)
    }

    func reset() {
        edgeMetadata.removeAll()
        engine.replaceState(.empty)
    }

    private func handleEngineDelta(_ delta: GraphDelta, final: GraphState) {
        for id in delta.deletedEdges {
            edgeMetadata.removeValue(forKey: id)
        }
        syncGraphComponents(delta: delta, final: final)
        onChange?()
    }

    private func syncGraphComponents(delta: GraphDelta, final: GraphState) {
        if Thread.isMainThread {
            syncGraphComponentsOnMain(delta: delta, final: final)
        } else {
            Task { @MainActor in
                self.syncGraphComponentsOnMain(delta: delta, final: final)
            }
        }
    }

    @MainActor
    private func syncGraphComponentsOnMain(delta: GraphDelta, final: GraphState) {
        for id in delta.deletedEdges {
            graph.removeEdge(ConnectionEdgeID(id))
        }
        for id in delta.deletedVertices {
            graph.removeNode(ConnectionNodeID(id))
        }

        for id in delta.createdVertices {
            guard let v = final.vertices[id] else { continue }
            let nodeID = ConnectionNodeID(id)
            if !graph.nodes.contains(nodeID) {
                graph.addNode(nodeID)
            }
            graph.setComponent(TraceVertexComponent(point: v.point), for: nodeID)
        }

        for id in delta.createdEdges {
            guard let e = final.edges[id] else { continue }
            let edgeID = ConnectionEdgeID(id)
            if !graph.edges.contains(edgeID) {
                graph.addEdge(edgeID)
            }
            let metadata = edgeMetadata[id]
            guard let start = final.vertices[e.start],
                let end = final.vertices[e.end]
            else { continue }
            let component = TraceEdgeComponent(
                id: id,
                start: ConnectionNodeID(e.start),
                end: ConnectionNodeID(e.end),
                startPoint: start.point,
                endPoint: end.point,
                width: metadata?.width ?? 1.0,
                layerId: metadata?.layerId
            )
            graph.setComponent(component, for: edgeID)
        }

        for (id, (_, to)) in delta.movedVertices {
            let nodeID = ConnectionNodeID(id)
            if var component = graph.component(TraceVertexComponent.self, for: nodeID) {
                component.point = to
                graph.setComponent(component, for: nodeID)
            }
        }

        // Ensure edge components track metadata changes (splits/merges).
        for (edgeID, edge) in final.edges {
            let metadata = edgeMetadata[edgeID]
            guard let start = final.vertices[edge.start],
                let end = final.vertices[edge.end]
            else { continue }
            let desired = TraceEdgeComponent(
                id: edgeID,
                start: ConnectionNodeID(edge.start),
                end: ConnectionNodeID(edge.end),
                startPoint: start.point,
                endPoint: end.point,
                width: metadata?.width ?? 1.0,
                layerId: metadata?.layerId
            )

            let graphConnectionEdgeID = ConnectionEdgeID(edgeID)
            if let existing = graph.component(TraceEdgeComponent.self, for: graphConnectionEdgeID) {
                if existing.start != desired.start ||
                    existing.end != desired.end ||
                    existing.startPoint != desired.startPoint ||
                    existing.endPoint != desired.endPoint ||
                    existing.width != desired.width ||
                    existing.layerId != desired.layerId {
                    graph.setComponent(desired, for: graphConnectionEdgeID)
                }
            } else {
                if !graph.edges.contains(graphConnectionEdgeID) {
                    graph.addEdge(graphConnectionEdgeID)
                }
                graph.setComponent(desired, for: graphConnectionEdgeID)
            }
        }
    }

    private func getOrCreateVertex(at point: CGPoint, in state: inout GraphState, tolerance: CGFloat) -> UUID {
        if let existing = state.findVertex(at: point, tol: tolerance) {
            return existing.id
        }
        return state.addVertex(at: point).id
    }
}

// MARK: - ConnectionEngine
extension TraceEngine {
    func beginDrag(selectedIDs: Set<UUID>) -> Bool { false }
    func updateDrag(by delta: CGPoint) {}
    func endDrag() {}
}
