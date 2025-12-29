# CanvasKit Architecture Roadmap

## Current Status
CoreConnection module created ✓

---

## Phase 1: CanvasRenderable Migration (IN PROGRESS)

Make all canvas elements conform to `CanvasRenderable` protocol, replacing the legacy `GraphComponent` + Provider pattern.

### Items (CanvasRenderable + CanvasDraggable)
- [x] `ComponentInstance` — symbols with pins and text
- [ ] Standalone text elements
- [ ] Graphics primitives (rectangles, lines, etc.)
- [ ] Footprints (PCB layout)
- [ ] Pads (PCB layout)

### Connections (managed by ConnectionEngine)
- [ ] Wire edges/vertices (via `WireEngine`)
- [ ] Trace edges/vertices (via `TraceEngine`)

### Cleanup
- [ ] Remove legacy `GraphSymbolRenderProvider`, `GraphSymbolHaloProvider`, `GraphSymbolHitTestProvider`
- [ ] Remove legacy `GraphPinRenderProvider`, `GraphPinHaloProvider`, `GraphPinHitTestProvider`
- [ ] Remove legacy `GraphTextRenderProvider`, `GraphTextHaloProvider`, `GraphTextHitTestProvider`
- [ ] Remove legacy `GraphFootprintRenderProvider`, `GraphFootprintHaloProvider`, `GraphFootprintHitTestProvider`
- [ ] Remove legacy `GraphPadRenderProvider`, `GraphPadHaloProvider`, `GraphPadHitTestProvider`

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
