# CanvasKit Architecture Roadmap

## Current Status
- CoreConnection module created ✓
- Dead code cleanup started ✓

---

## Phase 1: CanvasRenderable Migration (IN PROGRESS)

### Architecture Understanding

**Dual System:**
- `CanvasRenderable` → composite read-only rendering (symbols + pins + text as one unit)
- `GraphComponent` → editable individual elements (text editing, pin editing, dragging)

### Items (CanvasRenderable + CanvasDraggable)
- [x] `ComponentInstance` — symbols with pins and text

### Connections (managed by ConnectionEngine)
- [x] Wire edges/vertices (via `WireEngine`) — already handled
- [x] Trace edges/vertices (via `TraceEngine`) — already handled

### Cleanup
- [x] Remove `GraphSymbolRenderProvider` — DELETED (superseded by CanvasRenderableProvider)
- [x] Remove `GraphSymbolHaloProvider` — DELETED (superseded by CanvasRenderableHaloProvider)
- [x] Remove `GraphSymbolHitTestProvider` — DELETED (superseded by CanvasRenderableHitTestProvider)

### Kept (Still Needed)
- [x] `GraphSymbolComponent` — data model for dragging/editing symbols ✓
- [x] `GraphTextComponent` + providers — for text selection/editing system ✓
- [x] `GraphPinComponent` + providers — for junction dots + symbol editor ✓

---

## Phase 2: CoreConnection Integration

### ConnectionPoint conformance
- [ ] Make `PinDefinition` conform to `ConnectionPoint`
- [ ] Make pad connection points conform to `ConnectionPoint`

### ConnectionEngine enhancements
- [ ] Have `TraceEngine` conform to `ConnectionEngine`
- [ ] Add connection rule abstraction (if needed)

---

## Phase 3: CanvasView Simplification

- [ ] Simplify `CanvasView` API to work directly with `CanvasRenderable` items
- [ ] Reduce `CanvasEnvironment` dependencies
- [ ] Clean up refresh/observation patterns

---

## Future Considerations

### Unify Drag Systems
Currently two drag systems exist:
- `CanvasDraggableInteraction` — for CanvasRenderable items (new)
- `DragInteraction` — for GraphComponent items (legacy)

Could potentially unify these, but `DragInteraction` handles text/wire dragging with graph sync.
