import AppKit

struct TraceView: CKView {
    @CKContext var context
    @CKEnvironment var environment
    let traceEngine: TraceEngine

    var body: some CKView {
        let traces = context.items.compactMap { $0 as? TraceSegment }
        let pointsByID = Dictionary(
            uniqueKeysWithValues: context.items.compactMap { $0 as? TraceVertex }
                .map { ($0.id, $0.position) }
        )
        CKGroup {
            for trace in traces {
                if let start = pointsByID[trace.startID],
                   let end = pointsByID[trace.endID] {
                    let showHalo = context.highlightedItemIDs.contains(trace.id)
                        || context.selectedItemIDs.contains(trace.id)
                    let color = context.layers.first { $0.id == trace.layerId }?.color
                        ?? environment.canvasTheme.textColor
                    CKLine(from: start, to: end)
                        .stroke(color, width: trace.width)
                        .halo(
                            showHalo ? (color.copy(alpha: 0.35) ?? .clear) : .clear,
                            width: trace.width + 4
                        )
                        .hoverable(trace.id)
                        .selectable(trace.id)
                }
            }
        }
    }
}
