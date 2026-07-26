# Arc + Polyline Primitive Types — Design

## Motivation

CircuitPro's canvas primitive model (`Model/Primitive/`) currently supports only
`CanvasLine`, `CanvasRectangle`, and `CanvasCircle`. This is the first of a series
of sub-projects toward KiCad import (symbol libraries → footprint libraries →
schematics → PCBs). KiCad symbol and footprint graphics lean heavily on arcs
(transistor/diode curves, connector notches) and multi-point polylines (IC body
outlines, filled arrow shapes), neither of which CircuitPro can currently
represent. Without them, KiCad import would have to silently drop or badly
approximate a large fraction of real-world symbol geometry.

This project adds real `CanvasArc` and `CanvasPolyline` primitive types,
independent of and useful beyond KiCad import (e.g. for hand-authoring symbols
and footprints later). The KiCad symbol importer itself is a separate,
follow-on spec that will build on top of this one.

## Scope

**In scope:**
- `CanvasArc` and `CanvasPolyline` data models, added as new `CanvasPrimitive`
  conformances.
- Integration into `AnyCanvasPrimitive` (the type-erased primitive enum used
  everywhere primitives are stored/manipulated).
- Path generation in `PrimitiveGeometry` (local-space path + bounding box).
- Rendering views (`ArcView`, `PolylineView`) that resolve color from the
  active layer at render time, consistent with every existing primitive.
- Inspector support for stroke width and filled toggle (already generic,
  should require no changes).
- Whole-primitive interaction: select, hover, drag-to-move, delete — the same
  baseline every primitive gets.

**Out of scope (deferred to later work):**
- `ArcTool` / `PolylineTool` for hand-drawing new arcs/polylines by clicking
  points on the canvas. A natural follow-up once the model exists, but not
  needed to unblock KiCad import (imported geometry doesn't need a drawing
  tool, just a data target).
- Per-vertex / per-handle interactive editing — reshaping an existing arc's
  angles or a polyline's individual points after creation. V1 primitives are
  edited by moving/rotating/deleting the whole shape, same granularity as
  other primitives get without dedicated handle logic.
- New custom icon assets for the element list / toolbar. Placeholder built-in
  SF Symbols are fine initially.
- The KiCad symbol importer itself (separate spec, depends on this one).

## Data model

Both live in `CircuitPro/Model/Primitive/`, alongside the existing three.

### `CanvasArc`

Mirrors `CanvasCircle`'s shape, with a center/radius/angle representation
(rather than KiCad's native 3-point start/mid/end) because it's consistent
with how `CanvasCircle` already works and is the natural fit for
angle-based editing if handle-based arc editing is added later. KiCad's
3-point arcs convert to this via circumcenter math at import time.

```swift
struct CanvasArc: CanvasPrimitive {
    let id: UUID
    var radius: CGFloat
    var startAngle: CGFloat   // radians
    var endAngle: CGFloat     // radians
    var position: CGPoint     // = center
    var rotation: CGFloat     // reserved; unused for now (angles already encode orientation)
    var strokeWidth: CGFloat
    var filled: Bool          // when true, the path closes start→end as a chord
    var layerId: UUID?
}
```

### `CanvasPolyline`

Points are stored in local space relative to a centroid anchor at creation
time, so `position`/`rotation` behave exactly like every other primitive —
moving or rotating the primitive moves/rotates the whole shape as a unit,
rather than requiring each point to be transformed individually by callers.

```swift
struct CanvasPolyline: CanvasPrimitive {
    let id: UUID
    var points: [CGPoint]     // local space, relative to `position`
    var isClosed: Bool
    var position: CGPoint
    var rotation: CGFloat
    var strokeWidth: CGFloat
    var filled: Bool          // solid polygon fill; requires isClosed to look sane
    var layerId: UUID?
}
```

## Integration points

This follows the existing 3-primitive pattern exactly, extended to 5:

- **`AnyCanvasPrimitive`** (`Model/Primitive/AnyCanvasPrimitive.swift`): add
  `.arc(CanvasArc)` and `.polyline(CanvasPolyline)` cases. Extend every
  computed-property switch (`id`, `layerId`, `position`, `rotation`,
  `strokeWidth`, `filled`), plus `displayName` and `symbol` (icon).
- **`PrimitiveGeometry.localPath`** (`Model/Primitive/PrimitiveGeometry.swift`):
  - Arc: `CGMutablePath.addArc(center: .zero, radius:, startAngle:, endAngle:,
    clockwise: false)`, then `closeSubpath()` if `filled`.
  - Polyline: `move(to: points[0])` + `addLine(to:)` per subsequent point,
    then `closeSubpath()` if `isClosed`.
  - `localBoundingBox` needs no changes — it already derives generically from
    `localPath(...).boundingBoxOfPath` plus a stroke-width inset.
- **New render views** in `Features/CanvasKit+CircuitPro/View/Primitive/`:
  `ArcView.swift` and `PolylineView.swift`, structurally identical to
  `CircleView`/`LineView`/`RectangleView` — resolve stroke color via
  `context.layers.first { $0.id == primitive.layerId }?.color ??
  environment.canvasTheme.textColor`, build the shape from
  `PrimitiveGeometry.localPath` wrapped in `CKPath` (the same
  arbitrary-geometry escape hatch `WireView`/`TraceView` already use, rather
  than adding new shape-builder types to the domain-agnostic
  `Framework/CanvasKit` layer). Wire both into `PrimitiveView`'s switch.
- **Inspector** (`PrimitiveStyleControlView<T: CanvasPrimitive>`): already
  generic over `CanvasPrimitive` — stroke width and filled-toggle controls
  apply to the new cases with no changes. Corner-radius control stays gated
  to `CanvasRectangle` only, as today.

## Compatibility

`AnyCanvasPrimitive`'s `Codable` conformance is Swift-synthesized
(keyed-by-case-name), so adding cases is purely additive: existing
project/library files keep decoding unchanged. Files saved *after* this
change that contain an arc or polyline primitive won't decode in older
CircuitPro builds — an expected one-way street, not a regression.

## Follow-on work (not this project)

- `ArcTool` / `PolylineTool` for hand-drawing.
- Per-vertex / per-handle reshaping.
- KiCad symbol library import (`.kicad_sym` → `SymbolDefinition`), which
  depends on this project being done.
