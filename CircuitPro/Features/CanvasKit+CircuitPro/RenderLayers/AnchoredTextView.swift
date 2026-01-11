

struct AnchoredTextView: CKView {
    @CKContext var context
    let entry: SymbolView.TextEntry

    var body: some CKView {
        let isHighlighted =
            context.highlightedItemIDs.contains(entry.id)
            || (entry.ownerID.map { context.highlightedItemIDs.contains($0) } ?? false)

        CKGroup {
            if isHighlighted, let haloPath = entry.haloPath {
                let color = (entry.haloColor ?? context.environment.schematicTheme.textColor)
                    .applyingOpacity(0.4)
                CKPath(path: haloPath).halo(color, width: 5.0)
            }

            if !entry.primitives.isEmpty {
                CKGroup(primitives: entry.primitives)
            }
        }
    }
}
